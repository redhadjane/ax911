import Foundation
import XCTest
@testable import HOPEmployee

// Xcode app-hosted tests only. Every request is intercepted; these tests never
// connect to the live HOP server or use a real employee credential.
final class HOPAPITests: XCTestCase {
    private func client(path: String, status: Int = 200, response: String = "{\"ok\":true}",
                        inspect: @escaping (URLRequest) throws -> Void = { _ in }) -> (HOPAPI, URLSession) {
        HOPTransportProtocol.registry.register(path: path) { request in
            try inspect(request)
            return (status, Data(response.utf8))
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HOPTransportProtocol.self]
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        return (HOPAPI(session: session), session)
    }

    func testAuthenticatedRequestSendsBearerAndAcceptHeaders() async throws {
        let path = "/api/native-transport-test/auth-header"
        let (api, session) = client(path: path) { request in
            XCTAssertEqual(request.url?.host, "www.houseofpizzagaffney.com")
            XCTAssertEqual(request.url?.scheme, "https")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer unit-test-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        }
        defer { session.invalidateAndCancel(); HOPTransportProtocol.registry.remove(path: path) }
        await api.authorize("unit-test-token")
        let result = try await api.request(path)
        XCTAssertTrue(result["ok"].flag)
    }

    func testQueryValuesRoundTripWithoutBecomingAdditionalParameters() async throws {
        let path = "/api/native-transport-test/query"
        let expected = ["q": "Mo & café / + #?", "week_start": "2026-09-01"]
        let (api, session) = client(path: path) { request in
            let url = try XCTUnwrap(request.url)
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            let items = components.queryItems ?? []
            XCTAssertEqual(items.count, expected.count)
            for (key, value) in expected { XCTAssertEqual(items.first(where: { $0.name == key })?.value, value) }
            XCTAssertNil(components.fragment)
            XCTAssertFalse(url.absoluteString.contains(" "))
            // Express treats a literal '+' as a form-encoded space. Escaping it
            // preserves phone/search values through the actual backend parser.
            XCTAssertTrue(components.percentEncodedQuery?.contains("%2B") == true)
        }
        defer { session.invalidateAndCancel(); HOPTransportProtocol.registry.remove(path: path) }
        _ = try await api.request(path, query: expected)
    }

    func testServerUserMessageTakesPriorityOverInternalError() async throws {
        let path = "/api/native-transport-test/error"
        let (api, session) = client(path: path, status: 409,
            response: "{\"user_message\":\"This week is locked. Ask your manager to reopen it.\",\"error\":\"INTERNAL_CONFLICT\",\"message\":\"Generic failure\"}")
        defer { session.invalidateAndCancel(); HOPTransportProtocol.registry.remove(path: path) }
        do {
            _ = try await api.request(path)
            XCTFail("A 409 response must not be returned as successful data.")
        } catch let failure as HOPAPIError {
            XCTAssertEqual(failure.status, 409)
            XCTAssertEqual(failure.message, "This week is locked. Ask your manager to reopen it.")
        } catch { XCTFail("Expected a structured HOPAPIError, received \(error).") }
    }

    func testPublicSignInDoesNotReuseAnExistingBearerToken() async throws {
        let path = "/api/employees/login"
        let (api, session) = client(path: path) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        }
        defer { session.invalidateAndCancel(); HOPTransportProtocol.registry.remove(path: path) }
        await api.authorize("unit-test-stale-token")
        _ = try await api.request(path, method: "POST", body: .object([
            "name": .string("Unit Test Only"), "pin": .string("0000")
        ]), tokenOverride: "")
    }
}

private final class HOPTransportRegistry: @unchecked Sendable {
    typealias Handler = (URLRequest) throws -> (Int, Data)
    private let lock = NSLock()
    private var handlers: [String: Handler] = [:]
    func register(path: String, handler: @escaping Handler) {
        lock.lock(); defer { lock.unlock() }; handlers[path] = handler
    }
    func take(path: String) -> Handler? {
        lock.lock(); defer { lock.unlock() }; return handlers.removeValue(forKey: path)
    }
    func remove(path: String) {
        lock.lock(); defer { lock.unlock() }; handlers.removeValue(forKey: path)
    }
}

private final class HOPTransportProtocol: URLProtocol {
    static let registry = HOPTransportRegistry()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, let handler = Self.registry.take(path: url.path) else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        do {
            let (status, data) = try handler(request)
            guard let response = HTTPURLResponse(url: url, statusCode: status,
                httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]) else {
                throw URLError(.badServerResponse)
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
