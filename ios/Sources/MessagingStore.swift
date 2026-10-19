import Foundation
import Combine
import AudioToolbox

struct HOPChatAlert: Identifiable, Equatable { let id: String; let conversationID: String; let title: String }

@MainActor final class HOPMessages: ObservableObject {
    let api: HOPAPI
    var sessionExpired: (() -> Void)?
    @Published private(set) var conversations: [HOPConversation] = []
    @Published private(set) var people: [HOPRecord] = []
    @Published private(set) var blockedIDs: Set<String> = []
    @Published private(set) var isManager = false
    @Published private(set) var messages: [HOPChatMessage] = []
    @Published private(set) var detail: HOPChatDetail?
    @Published private(set) var reports: [HOPRecord] = []
    @Published private(set) var loading = false
    @Published private(set) var loadingThread = false
    @Published private(set) var loadingOlder = false
    @Published private(set) var sending = false
    @Published private(set) var actionBusy = false
    @Published private(set) var drafts: [String: HOPChatDraft] = [:]
    @Published var error: String?
    @Published var notice: String?
    @Published var alert: HOPChatAlert?
    private(set) var employeeID = ""
    private(set) var activeConversationID: String?
    private var epoch = 0
    private var selection = UUID()
    private var summaryTicket: UUID?
    private var detailTicket: UUID?
    private var sessionLoaded = false
    private var readThrough: [String: Int64] = [:]
    private var seen: [String: String]?
    private var earliestHasMore = false
    var foreground = true
    var unread: Int { conversations.reduce(0) { $0 + $1.unread } }
    var hasMore: Bool { earliestHasMore }
    init(api: HOPAPI) { self.api = api }
    func bind(_ employeeID: String) {
        guard self.employeeID != employeeID else { return }
        epoch += 1; selection = UUID(); self.employeeID = employeeID; activeConversationID = nil
        conversations = []; people = []; messages = []; detail = nil; drafts = [:]; reports = []; blockedIDs = []
        loading = false; loadingThread = false; loadingOlder = false; sending = false; actionBusy = false
        error = nil; notice = nil; alert = nil; readThrough = [:]; seen = nil; sessionLoaded = false; isManager = false
        summaryTicket = nil; detailTicket = nil; earliestHasMore = false
    }
    private func request(_ path: String, body: JSONValue? = nil) async throws -> JSONValue {
        guard !employeeID.isEmpty else { throw CancellationError() }; let version = epoch
        do {
            let result = try await api.request("/api/staff-messages" + path, method: body == nil ? "GET" : "POST", body: body)
            guard version == epoch else { throw CancellationError() }; return result
        } catch let failure as HOPAPIError where failure.status == 401 {
            if version == epoch { sessionExpired?() }; throw failure
        }
    }
    private func handle(_ failure: Error, version: Int) {
        guard version == epoch, !(failure is CancellationError) else { return }
        if let apiError = failure as? HOPAPIError { error = apiError.message }
        else { error = "The connection ended before HOP confirmed the result. Your draft is still here. Tap Send to retry the same message safely." }
    }
    func loadSession(force: Bool = false) async {
        guard !employeeID.isEmpty, !sessionLoaded || force else { return }; let version = epoch
        do {
            let result = try await request("/session")
            guard version == epoch else { return }
            guard result["viewer"]["id"].text == employeeID else { sessionExpired?(); return }
            people = result["people"].records; blockedIDs = Set(result["blocked_ids"].values.map(\.text)); isManager = result["viewer"]["is_manager"].flag; sessionLoaded = true; error = nil
        } catch { handle(error, version: version) }
    }
    func refreshSummary() async {
        guard !employeeID.isEmpty, summaryTicket == nil, foreground else { return }
        let version = epoch, ticket = UUID(); summaryTicket = ticket; loading = true
        defer { if version == epoch, summaryTicket == ticket { summaryTicket = nil; loading = false } }
        do {
            let result = try await request("/conversations"); guard version == epoch else { return }
            let next = result["conversations"].values.map(HOPConversation.init)
            if let previous = seen, UserDefaults.standard.object(forKey: "hopForegroundAlerts") as? Bool != false,
               UserDefaults.standard.object(forKey: "hopAlertMessages") as? Bool != false,
               !HOPAlertPolicy.quiet(Date(), enabled: UserDefaults.standard.bool(forKey: "hopQuietHours"), start: UserDefaults.standard.object(forKey: "hopQuietStart") as? Int ?? 1320, end: UserDefaults.standard.object(forKey: "hopQuietEnd") as? Int ?? 420),
               let changed = next.first(where: { !$0.muted && $0.unread > 0 && !$0.lastMessageAt.isEmpty && previous[$0.id] != $0.lastMessageAt && $0.id != activeConversationID }) {
                let event = HOPChatAlert(id: changed.id + changed.lastMessageAt, conversationID: changed.id, title: changed.title)
                alert = event
                if UserDefaults.standard.object(forKey: "hopAlertSound") as? Bool != false { AudioServicesPlaySystemSound(1007) }
                Task { [weak self] in try? await Task.sleep(for: .seconds(8)); if self?.alert?.id == event.id { self?.alert = nil } }
            }
            seen = Dictionary(next.map { ($0.id, $0.lastMessageAt) }, uniquingKeysWith: { _, last in last })
            if conversations != next { conversations = next }
            error = nil
        } catch { handle(error, version: version) }
    }
    func open(_ id: String) async {
        guard UUID(uuidString: id) != nil else { return }
        if activeConversationID != id { activeConversationID = id; selection = UUID(); detailTicket = nil; loadingThread = false; messages = []; detail = nil; earliestHasMore = false; error = nil; notice = nil }
        await refreshThread()
    }
    func close(_ id: String) {
        guard activeConversationID == id else { return }; activeConversationID = nil; selection = UUID(); detailTicket = nil
        messages = []; detail = nil; loadingThread = false; loadingOlder = false; earliestHasMore = false
    }
    func refreshThread() async {
        guard let id = activeConversationID, detailTicket == nil, foreground else { return }
        let version = epoch, selected = selection, ticket = UUID(); detailTicket = ticket; loadingThread = true
        defer { if version == epoch, selected == selection, detailTicket == ticket { detailTicket = nil; loadingThread = false } }
        do {
            let result = try await request("/conversations/" + id)
            guard version == epoch, selected == selection, activeConversationID == id else { return }
            let next = HOPChatDetail(result), incoming = result["messages"].values.map(HOPChatMessage.init)
            if detail == nil { earliestHasMore = next.hasMore }
            detail = next; let merged = HOPChatPolicy.merge(messages, incoming); if messages != merged { messages = merged }; error = nil
            await markRead(id)
        } catch {
            if let failure = error as? HOPAPIError, [403,404].contains(failure.status), selected == selection { messages = []; detail = nil }
            handle(error, version: version)
        }
    }
    private func markRead(_ id: String) async {
        guard foreground, activeConversationID == id, let last = messages.last, last.sequence > (readThrough[id] ?? 0) else { return }
        let version = epoch
        do { _ = try await request("/conversations/\(id)/read", body: .object(["through_seq": .string(String(last.sequence))])); guard version == epoch else { return }; readThrough[id] = last.sequence; await refreshSummary() }
        catch { handle(error, version: version) }
    }
    func loadEarlier() async {
        guard let id = activeConversationID, let first = messages.first, earliestHasMore, !loadingOlder else { return }
        let version = epoch, selected = selection; loadingOlder = true
        defer { if version == epoch, selected == selection { loadingOlder = false } }
        do {
            let result = try await api.request("/api/staff-messages/conversations/" + id, query: ["before": String(first.sequence)])
            guard version == epoch, selected == selection else { return }
            messages = HOPChatPolicy.merge(messages, result["messages"].values.map(HOPChatMessage.init)); earliestHasMore = result["has_more"].flag
        } catch let failure as HOPAPIError where failure.status == 401 { if version == epoch { sessionExpired?() } }
        catch { handle(error, version: version) }
    }
    func setDraft(_ text: String, for id: String) { drafts[id] = (drafts[id] ?? HOPChatDraft()).updating(text) }
    func send(in id: String) async {
        guard !sending, activeConversationID == id, detail?.canSend == true, let draft = drafts[id], draft.isValid else { return }
        let version = epoch; sending = true; error = nil; notice = nil
        defer { if version == epoch { sending = false } }
        do {
            _ = try await request("/conversations/\(id)/messages", body: draft.requestBody)
            guard version == epoch else { return }
            if drafts[id]?.clientID == draft.clientID { drafts[id] = nil }; notice = "Sent"
            if activeConversationID == id { await refreshThread() }; await refreshSummary()
        } catch { handle(error, version: version) }
    }
    func direct(to id: String) async -> String? {
        guard UUID(uuidString: id) != nil, !actionBusy else { return nil }; let version = epoch; actionBusy = true; error = nil
        defer { if version == epoch { actionBusy = false } }
        do { let result = try await request("/direct", body: .object(["employee_id": .string(id)])); guard version == epoch, UUID(uuidString: result["id"].text) != nil else { return nil }; await refreshSummary(); return result["id"].text }
        catch { handle(error, version: version); return nil }
    }
    private func action(_ path: String, body: JSONValue, success: String) async -> Bool {
        guard !actionBusy else { return false }; let version = epoch; actionBusy = true; error = nil; notice = nil
        defer { if version == epoch { actionBusy = false } }
        do { _ = try await request(path, body: body); guard version == epoch else { return false }; notice = success; await refreshThread(); await refreshSummary(); return true }
        catch { handle(error, version: version); return false }
    }
    func mute(_ id: String, muted: Bool) async { _ = await action("/conversations/\(id)/mute", body: .object(["muted": .bool(muted)]), success: muted ? "Conversation muted" : "Conversation unmuted") }
    func block(_ id: String, blocked: Bool) async {
        guard UUID(uuidString: id) != nil else { return }
        if await action("/blocks/" + id, body: .object(["blocked": .bool(blocked)]), success: blocked ? "Direct messages blocked" : "Teammate unblocked") { if blocked { blockedIDs.insert(id) } else { blockedIDs.remove(id) } }
    }
    func report(_ id: String, reason: String) async -> Bool {
        guard UUID(uuidString: id) != nil, HOPChatPolicy.reportIsValid(reason) else { return false }
        return await action("/reports/" + id, body: .object(["reason": .string(reason.trimmingCharacters(in: .whitespacesAndNewlines))]), success: "Message reported to managers")
    }
    func loadReports() async {
        guard isManager else { return }; let version = epoch
        do { let result = try await request("/reports"); guard version == epoch else { return }; reports = result["reports"].records }
        catch { if version == epoch { reports = [] }; handle(error, version: version) }
    }
    func resolve(_ id: String) async { if await action("/reports/\(id)/resolve", body: .object([:]), success: "Report reviewed") { await loadReports() } }
}
