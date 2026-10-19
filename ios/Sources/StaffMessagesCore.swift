import Foundation

// Wire values are validated here; no messages or drafts are persisted to disk.
public struct HOPConversation: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let kind: String
    public let unread: Int
    public let muted: Bool
    public let managerOnly: Bool
    public let lastBody: String
    public let lastMessageAt: String
    public init(_ value: JSONValue) {
        id = value["id"].text; title = value["title"].text; kind = value["kind"].text
        let count = value["unread"].number
        unread = count.isFinite ? Int(min(1_000_000, max(0, count))) : 0; muted = value["muted"].flag
        managerOnly = value["manager_only"].flag; lastBody = value["last_body"].text; lastMessageAt = value["last_message_at"].text
    }
    public var isDirect: Bool { kind == "direct" }
    public var initial: String { isDirect ? String(title.split(separator: " ").prefix(2).compactMap(\.first)) : "#" }
    public func matches(_ query: String) -> Bool { query.isEmpty || title.localizedCaseInsensitiveContains(query) }
}

public struct HOPChatMessage: Identifiable, Equatable, Sendable {
    public let id: String
    public let sequence: Int64
    public let senderID: String
    public let senderName: String
    public let body: String
    public let createdAt: String
    public let clientID: String
    public init(_ value: JSONValue) {
        id = value["id"].text; sequence = max(0, Int64(value["seq"].text) ?? 0)
        senderID = value["sender_id"].text; senderName = value["sender_name"].text
        body = value["body"].text; createdAt = value["created_at"].text; clientID = value["client_id"].text
    }
    public func isRead(by peer: Int64?) -> Bool { peer.map { $0 >= sequence && sequence > 0 } ?? false }
}

public struct HOPChatDetail: Equatable, Sendable {
    public let id: String
    public let kind: String
    public let canSend: Bool
    public let muted: Bool
    public let blocked: Bool
    public let blockedByMe: Bool
    public let peerID: String
    public let peerReadSequence: Int64?
    public let hasMore: Bool
    public init(_ value: JSONValue) {
        let c = value["conversation"]
        id = c["id"].text; kind = c["kind"].text; canSend = c["can_send"].flag
        muted = c["muted"].flag; blocked = c["blocked"].flag; blockedByMe = c["blocked_by_me"].flag; peerID = c["peer_id"].text
        peerReadSequence = Int64(value["peer_read_seq"].text); hasMore = value["has_more"].flag
    }
}

public struct HOPChatDraft: Equatable, Sendable {
    public let text: String
    public let clientID: String
    public init(text: String = "", clientID: String = UUID().uuidString.lowercased()) { self.text = text; self.clientID = clientID }
    public var body: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    public func updating(_ text: String) -> HOPChatDraft {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return HOPChatDraft(text: text, clientID: normalized == body ? clientID : UUID().uuidString.lowercased())
    }
    public var isValid: Bool {
        !body.isEmpty && body.utf16.count <= 2_000 && !body.unicodeScalars.contains {
            $0.value <= 8 || (11...31).contains($0.value)
        }
    }
    public var requestBody: JSONValue { .object(["body": .string(body), "client_id": .string(clientID)]) }
}

public enum HOPChatPolicy {
    public static func merge(_ existing: [HOPChatMessage], _ incoming: [HOPChatMessage]) -> [HOPChatMessage] {
        var unique: [String: HOPChatMessage] = [:]
        for message in existing + incoming where UUID(uuidString: message.id) != nil { unique[message.id] = message }
        return unique.values.sorted { $0.sequence == $1.sequence ? $0.id < $1.id : $0.sequence < $1.sequence }
    }
    public static func reportIsValid(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return (3...500).contains(value.utf16.count) && !value.unicodeScalars.contains { $0.value <= 8 || (11...31).contains($0.value) }
    }
    public static func conversationID(from raw: String) -> String? {
        guard let url = URL(string: raw, relativeTo: URL(string: "https://www.houseofpizzagaffney.com")!)?.absoluteURL,
              url.scheme == "https", ["www.houseofpizzagaffney.com", "houseofpizzagaffney.com"].contains(url.host ?? ""),
              url.path == "/employee/messages/" || url.path == "/command/messages/",
              let fragment = url.fragment, let components = URLComponents(string: "https://local.invalid/?" + fragment),
              let value = components.queryItems?.first(where: { $0.name == "thread" })?.value, UUID(uuidString: value) != nil else { return nil }
        return value.lowercased()
    }
    public static func reminderWeek(_ record: HOPRecord) -> String? {
        let payload = record["payload"], direct = payload["week_start"].text
        if HOPCalendar.date(direct) != nil, HOPCalendar.tuesday(direct) == direct { return direct }
        let raw = payload["url"].text
        guard let url = URL(string: raw, relativeTo: URL(string: "https://www.houseofpizzagaffney.com")!)?.absoluteURL,
              url.scheme == "https", ["www.houseofpizzagaffney.com", "houseofpizzagaffney.com"].contains(url.host ?? ""),
              let fragment = url.fragment, fragment.hasPrefix("availability?"),
              let parts = URLComponents(string: "https://local.invalid/?" + String(fragment.dropFirst("availability?".count))),
              let week = parts.queryItems?.first(where: { $0.name == "week_start" })?.value,
              HOPCalendar.date(week) != nil, HOPCalendar.tuesday(week) == week else { return nil }
        return week
    }
}
