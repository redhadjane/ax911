import Foundation
import XCTest
#if canImport(HOPCore)
@testable import HOPCore
#else
@testable import HOPEmployee
#endif

final class StaffMessagesTests: XCTestCase {
    private let thread = "11111111-1111-4111-8111-111111111111"
    private let employee = "22222222-2222-4222-8222-222222222222"
    private func json(_ raw: String) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self, from: Data(raw.utf8)) }
    func testDraftValidationMatchesServerUTF16AndControls() {
        XCTAssertFalse(HOPChatDraft(text: "  \n ").isValid)
        XCTAssertTrue(HOPChatDraft(text: String(repeating: "a", count: 2000)).isValid)
        XCTAssertFalse(HOPChatDraft(text: String(repeating: "a", count: 2001)).isValid)
        XCTAssertTrue(HOPChatDraft(text: String(repeating: "🍕", count: 1000)).isValid)
        XCTAssertFalse(HOPChatDraft(text: String(repeating: "🍕", count: 1001)).isValid)
        XCTAssertTrue(HOPChatDraft(text: "Hello\nTeam\tHOP").isValid)
        for code in Array(0...8) + Array(11...31) { XCTAssertFalse(HOPChatDraft(text: "a" + String(UnicodeScalar(code)!) + "b").isValid) }
    }
    func testRetriesReuseIDButEditedMessagesGetNewID() {
        let draft = HOPChatDraft(text: "Hello team")
        XCTAssertEqual(draft.updating("  Hello team \n").clientID, draft.clientID)
        XCTAssertEqual(draft.requestBody, draft.requestBody)
        XCTAssertNotEqual(draft.updating("Different message").clientID, draft.clientID)
        XCTAssertEqual(draft.requestBody["body"].text, "Hello team")
        XCTAssertEqual(draft.requestBody["sender_id"], .null)
    }
    func testMergeDeduplicatesAndSortsBigintSequencesWithoutPrecisionLoss() throws {
        let a = HOPChatMessage(try json("{\"id\":\"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa\",\"seq\":\"9007199254740993\",\"body\":\"first\"}"))
        let b = HOPChatMessage(try json("{\"id\":\"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb\",\"seq\":\"9007199254740994\"}"))
        XCTAssertEqual(HOPChatPolicy.merge([b,a], [a]).map(\.id), [a.id,b.id])
        XCTAssertFalse(a.isRead(by: a.sequence - 1)); XCTAssertTrue(a.isRead(by: a.sequence))
    }
    func testTrustedThreadLinksAndNoExternalNavigation() {
        XCTAssertEqual(HOPChatPolicy.conversationID(from: "/employee/messages/#thread=\(thread)"), thread)
        XCTAssertEqual(HOPChatPolicy.conversationID(from: "https://www.houseofpizzagaffney.com/command/messages/#thread=\(thread)"), thread)
        XCTAssertNil(HOPChatPolicy.conversationID(from: "https://evil.example/employee/messages/#thread=\(thread)"))
        XCTAssertNil(HOPChatPolicy.conversationID(from: "http://www.houseofpizzagaffney.com/employee/messages/#thread=\(thread)"))
        XCTAssertNil(HOPChatPolicy.conversationID(from: "/employee/messages/#thread=not-a-uuid"))
    }
    func testAvailabilityReminderTargetsNextTuesdayNotCurrentWeek() throws {
        let record = HOPRecord(try json("{\"payload\":{\"type\":\"availability_reminder\",\"url\":\"/employee/#availability?week_start=2026-10-27\"}}"))
        XCTAssertEqual(HOPChatPolicy.reminderWeek(record), "2026-10-27")
        XCTAssertEqual(HOPLink.notification(record), .availability)
        XCTAssertNil(HOPChatPolicy.reminderWeek(HOPRecord(try json("{\"payload\":{\"week_start\":\"2026-10-26\"}}"))))
    }
    func testMessagesDoNotInvalidateScheduleAndReportsRespectLimits() throws {
        let record = HOPRecord(try json("{\"category\":\"staff_message\",\"payload\":{\"url\":\"/employee/messages/#thread=\(thread)\"}}"))
        XCTAssertEqual(HOPLink.notification(record), .messages)
        XCTAssertTrue(HOPRefreshPlan.sections(for: .messages).isEmpty)
        XCTAssertEqual(HOPRefreshPlan.sections(for: .home).count, 4)
        XCTAssertFalse(HOPChatPolicy.reportIsValid("no")); XCTAssertTrue(HOPChatPolicy.reportIsValid("reason"))
        XCTAssertFalse(HOPChatPolicy.reportIsValid(String(repeating: "a", count: 501)))
    }
    @MainActor func testStoreSendRetriesSafelyWithoutTouchingOtherAPIs() async throws {
        let fixture = ChatFixture(thread: thread, employee: employee)
        let (chat, session) = await fixture.client(); defer { session.invalidateAndCancel(); fixture.remove() }
        chat.bind(employee); await chat.loadSession(); await chat.refreshSummary(); await chat.open(thread)
        XCTAssertTrue(chat.detail?.canSend == true); XCTAssertEqual(chat.unread, 0)
        chat.setDraft("Retry me", for: thread); let clientID = try XCTUnwrap(chat.drafts[thread]?.clientID)
        fixture.failNextSend = true
        await chat.send(in: thread)
        XCTAssertEqual(chat.drafts[thread]?.clientID, clientID); XCTAssertNotNil(chat.error)
        await chat.send(in: thread)
        XCTAssertNil(chat.drafts[thread]); XCTAssertEqual(fixture.sentClientIDs, [clientID,clientID])
        XCTAssertEqual(chat.messages.count, 1); XCTAssertTrue(fixture.paths.allSatisfy { $0.hasPrefix("/api/staff-messages/") })
    }
    @MainActor func testLogoutDropsDraftsMessagesAndReports() async {
        let fixture = ChatFixture(thread: thread, employee: employee)
        let (chat, session) = await fixture.client(); defer { session.invalidateAndCancel(); fixture.remove() }
        chat.bind(employee); await chat.loadSession(); await chat.open(thread); chat.setDraft("private", for: thread)
        chat.bind("")
        XCTAssertTrue(chat.drafts.isEmpty); XCTAssertTrue(chat.messages.isEmpty); XCTAssertTrue(chat.people.isEmpty)
        XCTAssertNil(chat.detail); XCTAssertFalse(chat.isManager); XCTAssertNil(chat.activeConversationID)
    }
    @MainActor func test401EndsSessionAnd403KeepsSessionButHidesThread() async {
        let fixture = ChatFixture(thread: thread, employee: employee)
        let (chat, session) = await fixture.client(); defer { session.invalidateAndCancel(); fixture.remove() }
        chat.bind(employee); var ended = false; chat.sessionExpired = { ended = true; chat.bind("") }
        fixture.status = 403; await chat.open(thread)
        XCTAssertFalse(ended); XCTAssertNil(chat.detail); XCTAssertTrue(chat.messages.isEmpty)
        fixture.status = 401; await chat.refreshSummary()
        XCTAssertTrue(ended); XCTAssertEqual(chat.employeeID, ""); XCTAssertTrue(chat.conversations.isEmpty)
    }
    @MainActor func testBlockedConversationAndAnnouncementCannotSend() async {
        let fixture = ChatFixture(thread: thread, employee: employee)
        let (chat, session) = await fixture.client(); defer { session.invalidateAndCancel(); fixture.remove() }
        chat.bind(employee); fixture.canSend = false; await chat.open(thread); chat.setDraft("not allowed", for: thread)
        await chat.send(in: thread)
        XCTAssertTrue(fixture.sentClientIDs.isEmpty); XCTAssertNotNil(chat.drafts[thread])
    }
}

// Isolated URLProtocol per test. No live endpoint, credential, or employee record.
private final class ChatFixture: @unchecked Sendable {
    let id = UUID().uuidString
    let thread: String; let employee: String
    private let lock = NSLock()
    private var failure = false, responseStatus = 200, writable = true
    private var sentIDs: [String] = [], calls: [String] = [], delivered = false
    var failNextSend: Bool { get { lock.withLock { failure } } set { lock.withLock { failure = newValue } } }
    var status: Int { get { lock.withLock { responseStatus } } set { lock.withLock { responseStatus = newValue } } }
    var canSend: Bool { get { lock.withLock { writable } } set { lock.withLock { writable = newValue } } }
    var sentClientIDs: [String] { lock.withLock { sentIDs } }
    var paths: [String] { lock.withLock { calls } }
    init(thread: String, employee: String) { self.thread = thread; self.employee = employee }
    @MainActor func client() async -> (HOPMessages, URLSession) {
        ChatProtocol.registry.set(id, self)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [ChatProtocol.self]
        config.httpAdditionalHeaders = ["X-HOP-Test": id]; config.urlCache = nil; config.httpCookieStorage = nil
        let session = URLSession(configuration: config)
        // Explicit intercepted transport, never the default live client.
        let intercepted = HOPAPI(session: session); await intercepted.authorize("test-only-token")
        return (HOPMessages(api: intercepted), session)
    }
    func remove() { ChatProtocol.registry.remove(id) }
    func response(_ request: URLRequest) throws -> (Int, Data) {
        try lock.withLock {
            let path = request.url!.path; calls.append(path)
            guard request.value(forHTTPHeaderField: "Authorization") == "Bearer test-only-token", path.hasPrefix("/api/staff-messages/") else { throw URLError(.badURL) }
            if responseStatus != 200 { return (responseStatus, Data("{\"user_message\":\"Not authorized for this action.\"}".utf8)) }
            let body: String
            if path.hasSuffix("/session") { body = "{\"viewer\":{\"id\":\"\(employee)\",\"is_manager\":false},\"people\":[],\"blocked_ids\":[]}" }
            else if path.hasSuffix("/messages") {
                var data = request.httpBody ?? Data()
                if let stream = request.httpBodyStream { stream.open(); defer { stream.close() }; var buffer = [UInt8](repeating: 0, count: 4096); while stream.hasBytesAvailable { let size = stream.read(&buffer, maxLength: buffer.count); if size <= 0 { break }; data.append(buffer, count: size) } }
                let raw = try JSONDecoder().decode(JSONValue.self, from: data); sentIDs.append(raw["client_id"].text)
                if failure { failure = false; throw URLError(.networkConnectionLost) }
                delivered = true; body = "{\"duplicate\":false,\"message\":{\"id\":\"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa\",\"seq\":\"1\"}}"
            } else if path.hasSuffix("/conversations") { body = "{\"conversations\":[],\"unread\":0}" }
            else if path.hasSuffix("/read") { body = "{\"ok\":true}" }
            else { body = "{\"conversation\":{\"id\":\"\(thread)\",\"kind\":\"direct\",\"can_send\":\(writable)},\"messages\":\(delivered ? "[{\"id\":\"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa\",\"seq\":\"1\",\"sender_id\":\"\(employee)\",\"body\":\"Retry me\"}]" : "[]"),\"has_more\":false}" }
            return (200, Data(body.utf8))
        }
    }
}
private final class ChatRegistry: @unchecked Sendable {
    private let lock = NSLock(); private var fixtures: [String: ChatFixture] = [:]
    func set(_ key: String, _ value: ChatFixture) { lock.withLock { fixtures[key] = value } }
    func get(_ key: String) -> ChatFixture? { lock.withLock { fixtures[key] } }
    func remove(_ key: String) { _ = lock.withLock { fixtures.removeValue(forKey: key) } }
}
private final class ChatProtocol: URLProtocol {
    static let registry = ChatRegistry()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let fixture = Self.registry.get(request.value(forHTTPHeaderField: "X-HOP-Test") ?? ""), let url = request.url else { throw URLError(.badURL) }
            let (status, data) = try fixture.response(request)
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed); client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
