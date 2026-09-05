import UIKit
import WebKit

private final class LetterRenderer: UIPrintPageRenderer {
    var landscape = false
    override var paperRect: CGRect { CGRect(x: 0, y: 0, width: landscape ? 792 : 612, height: landscape ? 612 : 792) }
    override var printableRect: CGRect { paperRect.insetBy(dx: 18, dy: 18) }
}

@MainActor final class DocumentExporter: NSObject, WKNavigationDelegate {
    private let root: URL
    private let landscape: Bool
    private var web: WKWebView?
    private var completion: ((Result<Data, Error>) -> Void)?
    private var timeout: Task<Void, Never>?
    private var folder: URL?
    init(root: URL, landscape: Bool) { self.root = root; self.landscape = landscape }
    func render(html: String, in parent: UIView, completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        // No API bridge exists in this separate, script-free document web view.
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: landscape ? 1008 : 768, height: 1024), configuration: configuration)
        self.web = web
        web.navigationDelegate = self
        web.alpha = 0.01
        web.isUserInteractionEnabled = false
        parent.insertSubview(web, at: 0)
        do {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("hop-document-" + UUID().uuidString, isDirectory: true)
            self.folder = folder
            try FileManager.default.createDirectory(at: folder.appendingPathComponent("assets"), withIntermediateDirectories: true)
            for name in ["styles.css", "document-print.css", "usability-2026.css", "ipad-print.css", "assets/official-hop-logo.png"] {
                try FileManager.default.copyItem(at: root.appendingPathComponent(name), to: folder.appendingPathComponent(name))
            }
            let index = folder.appendingPathComponent("index.html")
            try Data(html.utf8).write(to: index, options: [.atomic, .completeFileProtection])
            web.loadFileURL(index, allowingReadAccessTo: folder)
        } catch { finish(.failure(error)); return }
        timeout = Task { try? await Task.sleep(nanoseconds: 20_000_000_000); if !Task.isCancelled { finish(.failure(ExportError.failed)) } }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task {
            // Wait for local logo decoding and web-font/layout completion, not a simulator.
            _ = try? await webView.evaluateJavaScript("Promise.all([document.fonts.ready,...Array.from(document.images).map(i=>i.decode().catch(()=>{}))]).then(()=>true)")
            guard completion != nil else { return }
            let renderer = LetterRenderer()
            renderer.landscape = landscape
            renderer.addPrintFormatter(webView.viewPrintFormatter(), startingAtPageAt: 0)
            let pages = renderer.numberOfPages
            guard pages > 0 && pages <= 60 else { finish(.failure(ExportError.failed)); return }
            let data = UIGraphicsPDFRenderer(bounds: renderer.paperRect).pdfData { context in
                renderer.prepare(forDrawingPages: NSRange(location: 0, length: pages))
                for page in 0..<pages { context.beginPage(); renderer.drawPage(at: page, in: renderer.paperRect) }
            }
            finish(.success(data))
        }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    private func finish(_ result: Result<Data, Error>) {
        guard let callback = completion else { return }
        completion = nil; timeout?.cancel(); timeout = nil
        web?.stopLoading(); web?.removeFromSuperview(); web = nil
        if let folder { try? FileManager.default.removeItem(at: folder) }; folder = nil
        callback(result)
    }
    enum ExportError: Error { case failed }
}
