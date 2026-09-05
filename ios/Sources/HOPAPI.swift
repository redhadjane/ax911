import Foundation

struct HOPAPIError: Error, LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { message }
}

private final class HOPRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Never forward a HOP bearer credential to another host or plain HTTP.
        let allowed = request.url?.scheme == "https" && request.url?.host == HOPAPI.baseURL.host
        completionHandler(allowed ? request : nil)
    }
}

actor HOPAPI {
    static let baseURL = URL(string: "https://www.houseofpizzagaffney.com")!
    private let session: URLSession
    private var token = ""
    private var authVersion = 0
    init(session: URLSession? = nil) {
        if let session { self.session = session }
        else {
            let config = URLSessionConfiguration.ephemeral
            config.urlCache = nil; config.httpCookieStorage = nil; config.httpShouldSetCookies = false
            config.timeoutIntervalForRequest = 25; config.timeoutIntervalForResource = 45
            self.session = URLSession(configuration: config, delegate: HOPRedirectGuard(), delegateQueue: nil)
        }
    }
    func authorize(_ token: String, version: Int = 0) { guard version >= authVersion else { return }; authVersion = version; self.token = token }

    func request(_ path: String, method: String = "GET", query: [String: String] = [:], body: JSONValue? = nil, tokenOverride: String? = nil) async throws -> JSONValue {
        guard path.hasPrefix("/api/"), !path.contains(".."), var components = URLComponents(url: Self.baseURL.appendingPathComponent(String(path.dropFirst())), resolvingAgainstBaseURL: false) else {
            throw HOPAPIError(status: 0, message: "The requested HOP action is not valid.")
        }
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        }
        guard let url = components.url else { throw HOPAPIError(status: 0, message: "The HOP address could not be opened.") }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
        req.httpMethod = method; req.setValue("application/json", forHTTPHeaderField: "Accept")
        let credential = tokenOverride ?? token
        if !credential.isEmpty { req.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try JSONEncoder().encode(body); req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw HOPAPIError(status: 0, message: "HOP returned an unreadable response.") }
        let decoded = try? JSONDecoder().decode(JSONValue.self, from: data)
        guard (200..<300).contains(http.statusCode) else {
            let userMessage = decoded?["user_message"].text ?? ""
            let detail = !userMessage.isEmpty ? userMessage : decoded?["error"].text ?? ""
            let alternate = decoded?["message"].text ?? ""
            throw HOPAPIError(status: http.statusCode, message: !detail.isEmpty ? detail : !alternate.isEmpty ? alternate : http.statusCode == 401 ? "Your session expired. Please sign in again." : "HOP could not complete this action (\(http.statusCode)).")
        }
        if http.statusCode == 204 { return .object([:]) }
        guard let decoded else { throw HOPAPIError(status: http.statusCode, message: "HOP returned an unexpected response. Please try again.") }
        return decoded
    }
}
