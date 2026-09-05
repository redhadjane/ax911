import UIKit
import WebKit
import SafariServices

final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

@MainActor final class CommandViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandlerWithReply {
    private let manager = ManagerSession()
    private let redirectGuard = NoRedirect()
    private lazy var transport: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 35
        configuration.timeoutIntervalForResource = 60
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration, delegate: redirectGuard, delegateQueue: nil)
    }()
    private var webView: WKWebView!
    private var root: URL { Bundle.main.resourceURL!.appendingPathComponent("Web", isDirectory: true) }
    private var exporter: DocumentExporter?
    private let privacyCover = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        configuration.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "hopNative")
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
        privacyCover.backgroundColor = .systemBackground
        privacyCover.isHidden = true
        privacyCover.frame = view.bounds
        privacyCover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(privacyCover)
        NotificationCenter.default.addObserver(self, selector: #selector(hidePrivateContent), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resumeContent), name: UIApplication.didBecomeActiveNotification, object: nil)
        loadWorkspace()
    }
    private func loadWorkspace() {
        let content = webView.configuration.userContentController
        content.removeAllUserScripts()
        let bootstrap = "window.__HOP_NATIVE_SESSION__ = \(manager.token == nil ? "false" : "true");"
        content.addUserScript(WKUserScript(source: bootstrap, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView.loadFileURL(root.appendingPathComponent("index.html"), allowingReadAccessTo: root)
    }
    @objc private func hidePrivateContent() { privacyCover.isHidden = false }
    @objc private func resumeContent() {
        privacyCover.isHidden = true
        webView.evaluateJavaScript("window.dispatchEvent(new Event('hop-resume'))", completionHandler: nil)
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard message.frameInfo.isMainFrame, CommandPolicy.isBundledPage(message.frameInfo.request.url, root: root),
              CommandPolicy.isBundledPage(webView.url, root: root), let body = message.body as? [String: Any], let action = body["action"] as? String else {
            replyHandler(nil, "This page does not have access to HOP native services."); return
        }
        switch action {
        case "logout": manager.clear(); replyHandler(true, nil)
        case "request":
            Task {
                do { replyHandler(try await request(body), nil) }
                catch { replyHandler(nil, (error as? LocalizedError)?.errorDescription ?? "Unable to reach HOP. Check your connection and try again.") }
            }
        case "share":
            guard let name = body["filename"] as? String, let safeName = CommandPolicy.exportName(name),
                  let base64 = body["base64"] as? String, base64.count <= 32_000_000, let data = Data(base64Encoded: base64) else {
                replyHandler(nil, "This export is invalid or too large."); return
            }
            do { try share(data: data, name: safeName); replyHandler(true, nil) }
            catch { replyHandler(nil, "The export could not be saved. Please try again.") }
        case "document":
            guard exporter == nil, let html = body["html"] as? String, html.utf8.count < 12_000_000 else {
                replyHandler(nil, "Another export is open, or the document is too large."); return
            }
            let document = DocumentExporter(root: root, landscape: body["landscape"] as? Bool == true)
            exporter = document
            document.render(html: html, in: view) { [weak self] result in
                guard let self else { return }
                self.exporter = nil
                switch result {
                case .success(let data):
                    let name = CommandPolicy.exportName(body["filename"] as? String ?? "HOP-Document.pdf") ?? "HOP-Document.pdf"
                    self.presentExportOptions(data: data, name: name, landscape: body["landscape"] as? Bool == true)
                    replyHandler(true, nil)
                case .failure: replyHandler(nil, "The document could not be rendered. Please reopen its preview and try again.")
                }
            }
        case "external":
            guard let value = body["url"] as? String, let url = CommandPolicy.externalURL(value) else { replyHandler(nil, "Unsupported link."); return }
            openExternal(url); replyHandler(true, nil)
        default: replyHandler(nil, "Unsupported iPad action.")
        }
    }
    private func request(_ body: [String: Any]) async throws -> [String: Any] {
        let method = (body["method"] as? String ?? "GET").uppercased()
        guard let value = body["url"] as? String, let url = CommandPolicy.apiURL(value, method: method) else { throw BridgeError.invalidEndpoint }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let login = url.path == "/api/command-auth/login" && method == "POST"
        if !login, let token = manager.token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let text = body["body"] as? String {
            guard text.utf8.count < 25_000_000 else { throw BridgeError.tooLarge }
            request.httpBody = Data(text.utf8)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse, data.count < 25_000_000 else { throw BridgeError.tooLarge }
        guard !(300...399).contains(http.statusCode) else { throw BridgeError.redirect }
        var output = data
        if login, (200...299).contains(http.statusCode) {
            guard var payload = try JSONSerialization.jsonObject(with: data) as? [String: Any], let token = payload["access_token"] as? String else { throw BridgeError.invalidSession }
            try manager.save(token)
            // The real token never enters JavaScript or localStorage.
            payload["access_token"] = "native-session"
            output = try JSONSerialization.data(withJSONObject: payload)
        } else if http.statusCode == 401 { manager.clear() }
        return ["status": http.statusCode, "body": output.base64EncodedString(), "contentType": http.value(forHTTPHeaderField: "Content-Type") ?? "application/json"]
    }
    private func share(data: Data, name: String) throws {
        guard presentedViewController == nil else { throw BridgeError.busy }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: folder) }
        anchor(activity.popoverPresentationController)
        present(activity, animated: true)
    }
    private func presentExportOptions(data: Data, name: String, landscape: Bool) {
        let menu = UIAlertController(title: "Export document", message: "Use the same PDF for AirPrint, sharing, or saving to Files.", preferredStyle: .actionSheet)
        menu.addAction(UIAlertAction(title: "Save PDF / Share", style: .default) { [weak self] _ in
            DispatchQueue.main.async { do { try self?.share(data: data, name: name) } catch { self?.showError("Close the current sheet and try exporting again.") } }
        })
        menu.addAction(UIAlertAction(title: "AirPrint", style: .default) { [weak self] _ in
            guard let self else { return }
            let printer = UIPrintInteractionController.shared
            let info = UIPrintInfo(dictionary: nil)
            info.jobName = name
            info.outputType = .general
            info.orientation = landscape ? .landscape : .portrait
            printer.printInfo = info
            printer.printingItem = data
            printer.present(from: CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxY - 60, width: 1, height: 1), in: self.view, animated: true, completionHandler: nil)
        })
        menu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        anchor(menu.popoverPresentationController)
        present(menu, animated: true)
    }
    private func anchor(_ popover: UIPopoverPresentationController?) {
        popover?.sourceView = view
        popover?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 60, width: 1, height: 1)
    }
    private func openExternal(_ url: URL) {
        if url.scheme == "https" { present(SFSafariViewController(url: url), animated: true) }
        else { UIApplication.shared.open(url) }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if CommandPolicy.isBundledPage(navigationAction.request.url, root: root), navigationAction.targetFrame?.isMainFrame != false { decisionHandler(.allow); return }
        if navigationAction.navigationType == .linkActivated, let value = navigationAction.request.url?.absoluteString, let url = CommandPolicy.externalURL(value) { openExternal(url) }
        decisionHandler(.cancel)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? { nil }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard frame.isMainFrame, CommandPolicy.isBundledPage(frame.request.url, root: root), presentedViewController == nil else { completionHandler(false); return }
        let alert = UIAlertController(title: "Confirm HOP action", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard frame.isMainFrame, CommandPolicy.isBundledPage(frame.request.url, root: root), presentedViewController == nil else { completionHandler(); return }
        let alert = UIAlertController(title: "HOP Command Center", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        showError("iPad closed the workspace to free memory. Reload to reconnect. Unsaved edits may need to be entered again.", reload: true)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { showError("The bundled workspace could not open.", reload: true) }
    private func showError(_ message: String, reload: Bool = false) {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: "HOP Command Center", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: reload ? "Reload" : "OK", style: .default) { [weak self] _ in if reload { self?.loadWorkspace() } })
        present(alert, animated: true)
    }
    enum BridgeError: LocalizedError {
        case invalidEndpoint, tooLarge, redirect, invalidSession, busy
        var errorDescription: String? {
            switch self {
            case .invalidEndpoint: return "Only the connected HOP HTTPS API is allowed."
            case .tooLarge: return "This record or image is too large. Try a smaller image."
            case .redirect: return "The HOP server redirected this request. Please check the server configuration."
            case .invalidSession: return "HOP did not return a valid manager session."
            case .busy: return "Close the current sheet before exporting another file."
            }
        }
    }
}
