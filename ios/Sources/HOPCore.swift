import Foundation

// HOP's API contains legacy numeric strings and optional fields. Preserve those
// wire values here; views use the named accessors below instead of inventing data.
public enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    public init(from decoder: Decoder) throws {
        let box = try decoder.singleValueContainer()
        if box.decodeNil() { self = .null }
        else if let value = try? box.decode(Bool.self) { self = .bool(value) }
        else if let value = try? box.decode(Double.self) { self = .number(value) }
        else if let value = try? box.decode(String.self) { self = .string(value) }
        else if let value = try? box.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try box.decode([String: JSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var box = encoder.singleValueContainer()
        switch self {
        case .object(let v): try box.encode(v)
        case .array(let v): try box.encode(v)
        case .string(let v): try box.encode(v)
        case .number(let v): try box.encode(v)
        case .bool(let v): try box.encode(v)
        case .null: try box.encodeNil()
        }
    }
    public subscript(_ key: String) -> JSONValue { if case .object(let v) = self { return v[key] ?? .null }; return .null }
    public var text: String {
        switch self { case .string(let v): return v; case .number(let v): return v.rounded() == v ? String(format: "%.0f", v) : String(v); default: return "" }
    }
    public var number: Double { if case .number(let v) = self { return v }; return Double(text) ?? 0 }
    public var flag: Bool { if case .bool(let v) = self { return v }; return text == "true" || text == "1" || number == 1 }
    public var values: [JSONValue] { if case .array(let v) = self { return v }; return [] }
    public var fields: [String: JSONValue] { if case .object(let v) = self { return v }; return [:] }
    public var records: [HOPRecord] { values.map(HOPRecord.init) }
}

public struct HOPRecord: Codable, Equatable, Identifiable, Sendable {
    public var raw: JSONValue
    public init(_ raw: JSONValue) { self.raw = raw }
    public subscript(_ key: String) -> JSONValue { raw[key] }
    public var id: String { first("id", "assignment_id", "employee_id", "code") }
    public func first(_ keys: String...) -> String { keys.map { raw[$0].text }.first { !$0.isEmpty } ?? "" }
    public var name: String { first("display_name", "employee_name", "full_name", "name") }
    public var status: String { first("status", "state") }
    public var isRead: Bool { !raw["read_at"].text.isEmpty || raw["read"].flag }
    public var title: String { first("title", "reward_title", "description", "type") }
    public func setting(_ key: String, _ value: JSONValue) -> HOPRecord {
        var fields = raw.fields; fields[key] = value; return HOPRecord(.object(fields))
    }
}

public enum HOPCalendar {
    public static let zone = TimeZone(identifier: "America/New_York")!
    public static var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = zone; return c }
    public static func today(_ date: Date = Date()) -> String { key(date) }
    public static func key(_ date: Date) -> String {
        let f = DateFormatter(); f.calendar = calendar; f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = zone; f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    // Database date fields may arrive as ISO midnight timestamps. The first ten
    // characters represent the calendar date, never an instant to timezone-shift.
    public static func date(_ value: String) -> Date? {
        let text = String(value.prefix(10))
        guard text.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil else { return nil }
        let f = DateFormatter(); f.calendar = calendar; f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = zone; f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
        guard let date = f.date(from: text), key(date) == text else { return nil }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)
    }
    public static func add(_ key: String, days: Int) -> String {
        guard let date = date(key), let result = calendar.date(byAdding: .day, value: days, to: date) else { return key }
        return self.key(result)
    }
    public static func tuesday(_ key: String) -> String {
        guard let d = date(key) else { return key }
        let weekday = calendar.component(.weekday, from: d) - 1
        return add(key, days: -((weekday - 2 + 7) % 7))
    }
    public static func shiftDate(week: String, day: Int) -> String { add(tuesday(week), days: (day - 2 + 7) % 7) }
    public static func label(_ key: String, format: String = "EEE, MMM d") -> String {
        guard let d = date(key) else { return key.isEmpty ? "Date not provided" : key }
        let f = DateFormatter(); f.calendar = calendar; f.timeZone = zone; f.locale = .current; f.dateFormat = format; return f.string(from: d)
    }
    public static func clock(_ value: String) -> String {
        guard let minutes = minutes(value) else { return value }
        return "\((minutes / 60) % 12 == 0 ? 12 : (minutes / 60) % 12):\(String(format: "%02d", minutes % 60)) \(minutes < 720 ? "AM" : "PM")"
    }
    public static func minutes(_ value: String) -> Int? {
        let bits = value.split(separator: ":")
        guard bits.count >= 2, let hour = Int(bits[0]), let minute = Int(bits[1].prefix(2)), (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }
    public static func labelTimes(_ label: String) -> [String] {
        let normalized = label.replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-").replacingOccurrences(of: "−", with: "-")
        guard let regex = try? NSRegularExpression(pattern: "(\\d{1,2}(?::\\d{2})?)\\s*(AM|PM)?\\s*-\\s*(\\d{1,2}(?::\\d{2})?)\\s*(AM|PM)?", options: .caseInsensitive),
              let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) else { return [] }
        func capture(_ i: Int) -> String { guard let range = Range(match.range(at: i), in: normalized) else { return "" }; return String(normalized[range]).uppercased() }
        func time(_ clock: String, _ meridiem: String) -> String? {
            let pieces = clock.split(separator: ":")
            guard var h = Int(pieces[0]), let m = Int(pieces.count > 1 ? String(pieces[1]) : "0"), (0...59).contains(m), (meridiem.isEmpty ? (0...23).contains(h) : (1...12).contains(h)) else { return nil }
            if meridiem == "PM" && h < 12 { h += 12 }; if meridiem == "AM" && h == 12 { h = 0 }
            return String(format: "%02d:%02d", h, m)
        }
        let am = capture(2).isEmpty ? capture(4) : capture(2), pm = capture(4).isEmpty ? capture(2) : capture(4)
        guard let start = time(capture(1), am), let end = time(capture(3), pm) else { return [] }
        return [start, end]
    }
    public static func instant(day: String, time: String) -> Date? {
        guard let date = date(day), let min = minutes(time) else { return nil }
        return calendar.date(bySettingHour: min / 60, minute: min % 60, second: 0, of: date)
    }
}

public struct HOPShift: Identifiable, Equatable, Sendable {
    public let entry: HOPRecord
    public let row: HOPRecord
    public let date: String
    public var id: String { entry.id }
    public var employeeID: String { entry["employee_id"].text }
    public var employeeName: String { entry.name }
    public var slot: String { row.first("label", "row_label", "row_key") }
    public var start: String { !entry["start_time"].text.isEmpty ? entry["start_time"].text : HOPCalendar.labelTimes(entry["shift_label"].text).first ?? "" }
    public var end: String { !entry["end_time"].text.isEmpty ? entry["end_time"].text : HOPCalendar.labelTimes(entry["shift_label"].text).last ?? "" }
    public var time: String { if !start.isEmpty && !end.isEmpty { return "\(HOPCalendar.clock(start)) – \(HOPCalendar.clock(end))" }; return entry.first("shift_label") }
    public var roleKey: String {
        let values = "\(row.first("role_group", "role")) \(slot) \(row["row_key"].text) \(entry["role"].text)".lowercased()
        if values.contains("host") { return "host" }
        if values.contains("support") || values.contains("floor") || values.contains("fh") { return "support" }
        return "main"
    }
    public var role: String { roleKey == "host" ? "Hosting" : roleKey == "support" ? "Floor help" : "Serving" }
    public var minutes: Int? {
        guard let a = HOPCalendar.minutes(start), let b = HOPCalendar.minutes(end) else { return nil }
        return b >= a ? b - a : b + 1440 - a
    }
    public var endInstant: Date? {
        guard let end = HOPCalendar.instant(day: date, time: end) else { return nil }
        return (HOPCalendar.minutes(self.end) ?? 0) < (HOPCalendar.minutes(start) ?? 0) ? HOPCalendar.calendar.date(byAdding: .day, value: 1, to: end) : end
    }
    public var startInstant: Date? { HOPCalendar.instant(day: date, time: start) }
    public func named(_ name: String) -> HOPShift { HOPShift(entry: entry.setting("employee_name", .string(name)), row: row, date: date) }
    public static func from(_ payload: JSONValue, week: String, employeeID: String? = nil) -> [HOPShift] {
        guard payload["fallback"] != .bool(true), payload["database_available"] != .bool(false) else { return [] }
        let schedule = payload["schedule"] == .null ? payload : payload["schedule"]
        guard schedule["status"].text.isEmpty || schedule["status"].text == "published" else { return [] }
        let rows = schedule["rows"].records
        var seen = Set<String>()
        let all = schedule["entries"].records
        return all.compactMap { entry -> HOPShift? in
            guard !entry["employee_id"].text.isEmpty, employeeID == nil || entry["employee_id"].text == employeeID,
                  let day = Int(entry["day_of_week"].text), [0,2,3,4,5,6].contains(day) else { return nil }
            let cell = all.filter { $0["row_id"].text == entry["row_id"].text && $0["day_of_week"].text == entry["day_of_week"].text }
            let notes = cell.map { $0.first("notes", "note").uppercased() }.joined(separator: " ")
            if notes.contains("HOP_SLOT_INACTIVE") && !notes.contains("HOP_SLOT_ACTIVE") { return nil }
            let row = rows.first { $0.id == entry["row_id"].text } ?? HOPRecord(.object([:]))
            let unique = "\(entry["row_id"].text)|\(day)|\(entry["employee_id"].text)"
            guard seen.insert(unique).inserted else { return nil }
            var canonical = entry
            if let time = cell.first(where: { !$0["start_time"].text.isEmpty || !$0["shift_label"].text.isEmpty || !$0["end_time"].text.isEmpty }) {
                for key in ["start_time", "end_time", "shift_label"] { if !time[key].text.isEmpty { canonical = canonical.setting(key, time[key]) } }
            }
            return HOPShift(entry: canonical, row: row, date: HOPCalendar.shiftDate(week: week, day: day))
        }.sorted { ($0.date, $0.start, $0.id) < ($1.date, $1.start, $1.id) }
    }
}

public enum HOPLink: String, Hashable, Sendable { case home, schedule, requests, notifications, profile, availability, tasks, parties, club
    public static func notification(_ record: HOPRecord) -> HOPLink {
        let p = record["payload"]
        let hint = [record["category"].text, p["type"].text, p["url"].text, p["screen"].text, p["route"].text, record["title"].text].joined(separator: " ").lowercased()
        if hint.contains("shift_switch") || hint.contains("shift-switch") || hint.contains("request") { return .requests }
        if hint.contains("availab") { return .availability }
        if hint.contains("schedule") { return .schedule }
        if hint.contains("task") { return .tasks }
        if hint.contains("part") { return .parties }
        return .notifications
    }
}

public enum HOPExport {
    private static func escape(_ text: String) -> String { text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: ";", with: "\\;").replacingOccurrences(of: ",", with: "\\,").replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "") }
    public static func calendar(_ shifts: [HOPShift], now: Date = Date()) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        var lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//House of Pizza//Employee Schedule//EN", "CALSCALE:GREGORIAN"]
        for shift in shifts {
            guard let start = HOPCalendar.instant(day: shift.date, time: shift.start), let end = shift.endInstant else { continue }
            lines += ["BEGIN:VEVENT", "UID:\(escape(shift.id))@houseofpizzagaffney.com", "DTSTAMP:\(f.string(from: now))", "DTSTART:\(f.string(from: start))", "DTEND:\(f.string(from: end))", "SUMMARY:\(escape("HOP · " + shift.role))", "DESCRIPTION:\(escape(shift.slot + " · " + shift.time))", "END:VEVENT"]
        }
        lines += ["END:VCALENDAR"]; return lines.joined(separator: "\r\n") + "\r\n"
    }
}
