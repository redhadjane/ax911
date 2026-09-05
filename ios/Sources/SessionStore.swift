import Foundation
import SwiftUI
import Security

struct EmployeeSession: Codable {
    var employee: HOPRecord
    var token: String
    var expiresAt: Date
}

private struct ScheduleSnapshot: Codable { let savedAt: Date; let sections: [String: JSONValue] }
private enum ScheduleCache {
    private static func url(employee: String, week: String) -> URL? {
        guard UUID(uuidString: employee) != nil, HOPCalendar.date(week) != nil else { return nil }
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("HOPPublishedSchedules", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(employee)-\(String(week.prefix(10))).json")
    }
    static func read(employee: String, week: String) -> ScheduleSnapshot? {
        guard let url = url(employee: employee, week: week), let bytes = try? Data(contentsOf: url), let snapshot = try? JSONDecoder().decode(ScheduleSnapshot.self, from: bytes), Date().timeIntervalSince(snapshot.savedAt) < 14 * 86400 else { return nil }
        return snapshot
    }
    static func write(employee: String, week: String, sections: [String: JSONValue]) {
        let retained = sections.filter { ["mine", "team", "next", "directory"].contains($0.key) }
        guard !retained.isEmpty, let url = url(employee: employee, week: week), let bytes = try? JSONEncoder().encode(ScheduleSnapshot(savedAt: Date(), sections: retained)) else { return }
        try? bytes.write(to: url, options: [.atomic, .completeFileProtection])
    }
    static func clear(employee: String) {
        guard UUID(uuidString: employee) != nil, let example = url(employee: employee, week: HOPCalendar.tuesday(HOPCalendar.today())) else { return }
        let directory = example.deletingLastPathComponent()
        for file in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] where file.lastPathComponent.hasPrefix(employee + "-") && file.pathExtension == "json" { try? FileManager.default.removeItem(at: file) }
    }
}

enum SessionKeychain {
    private static let service = "com.houseofpizzagaffney.employee.session"
    static func write(_ data: Data, account: String = "employee") throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecItemNotFound {
            var new = query; new[kSecValueData as String] = data; new[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let status = SecItemAdd(new as CFDictionary, nil)
            guard status == errSecSuccess else { throw HOPAPIError(status: Int(status), message: "Secure sign-in could not be saved on this iPhone.") }
        } else if update != errSecSuccess { throw HOPAPIError(status: Int(update), message: "Secure sign-in could not be updated.") }
    }
    static func read(account: String = "employee") -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?; guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }; return result as? Data
    }
    static func clear(account: String = "employee") {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] as CFDictionary)
    }
}

@MainActor final class HOPStore: ObservableObject {
    let api = HOPAPI()
    @Published var employee: HOPRecord?
    @Published var screen: HOPLink = .home
    @Published var week = HOPCalendar.tuesday(HOPCalendar.today())
    @Published var data: [String: JSONValue] = [:]
    @Published var errors: [String: String] = [:]
    @Published var loading = false
    @Published var busy = false
    @Published var message: String?
    @Published var loginError: String?
    @Published var lastRefresh: Date?
    private var generation = 0
    private var sessionVersion = 0
    private var expiry = Date.distantPast

    func restore() async {
        guard let encoded = SessionKeychain.read(), let session = try? JSONDecoder().decode(EmployeeSession.self, from: encoded) else { return }
        guard session.expiresAt > Date() else { logout(); loginError = "Please sign in again to see your latest schedule."; return }
        sessionVersion += 1; employee = session.employee; expiry = session.expiresAt; await api.authorize(session.token, version: sessionVersion)
        loadSnapshot()
        await refresh()
    }
    func login(name: String, pin: String) async {
        guard !busy else { return }; busy = true; defer { busy = false }; loginError = nil
        sessionVersion += 1; let attempt = sessionVersion
        do {
            let result = try await api.request("/api/employees/login", method: "POST", body: .object(["name": .string(name.trimmingCharacters(in: .whitespacesAndNewlines)), "pin": .string(pin)]), tokenOverride: "")
            let person = HOPRecord(result["employee"]), token = result["access_token"].text
            guard attempt == sessionVersion else { return }
            guard !person.id.isEmpty, !token.isEmpty, person.status == "active" else { throw HOPAPIError(status: 401, message: "HOP did not return an active employee session.") }
            let session = EmployeeSession(employee: minimalIdentity(person), token: token, expiresAt: Date().addingTimeInterval(result["expires_in"].number))
            try SessionKeychain.write(JSONEncoder().encode(session))
            employee = person; expiry = session.expiresAt; week = HOPCalendar.tuesday(HOPCalendar.today()); screen = .home; await api.authorize(token, version: attempt)
            loadSnapshot()
            await refresh()
        } catch { loginError = error.localizedDescription }
    }
    func logout() {
        if let employee { ScheduleCache.clear(employee: employee.id) }
        sessionVersion += 1; let version = sessionVersion
        generation += 1; SessionKeychain.clear(); SessionKeychain.clear(account: "club")
        employee = nil; data = [:]; errors = [:]; expiry = .distantPast; loading = false; message = nil; lastRefresh = nil
        Task { await api.authorize("", version: version) }
    }
    func refresh() async {
        guard let person = employee else { return }
        guard expiry > Date() else { logout(); loginError = "Your sign-in expired. Enter your PIN again."; return }
        generation += 1; let run = generation; let requestedWeek = week
        loading = true
        let endpoints: [(String, String, [String: String])] = [
            ("mine", "/api/schedules/employee/\(person.id)/\(requestedWeek)", [:]),
            ("team", "/api/schedules/published/\(requestedWeek)", [:]),
            ("next", "/api/schedules/employee/\(person.id)/\(HOPCalendar.add(requestedWeek, days: 7))", [:]),
            ("availability", "/api/availability/employee/\(person.id)", ["week_start": requestedWeek]),
            ("pending", "/api/inbox/pending", ["employee_id": person.id]),
            ("history", "/api/inbox/history", ["employee_id": person.id]),
            ("swaps", "/api/shift-switch/employee/\(person.id)", [:]),
            ("notifications", "/api/notifications/employee/\(person.id)", [:]),
            ("tasks", "/api/tasks/employee/\(person.id)", ["week_start": requestedWeek]),
            ("parties", "/api/parties", ["week_start": requestedWeek]),
            ("directory", "/api/employees", [:]),
            ("profile", "/api/employees/\(person.id)", [:])
        ]
        await withTaskGroup(of: (String, JSONValue?, String?, Int).self) { group in
            for (key, path, query) in endpoints {
                group.addTask { [api] in
                    do { return (key, try await api.request(path, query: query), nil, 200) }
                    catch let error as HOPAPIError { return (key, nil, error.message, error.status) }
                    catch { return (key, nil, error.localizedDescription, 0) }
                }
            }
            for await (key, payload, error, status) in group {
                guard generation == run, employee?.id == person.id, week == requestedWeek else { continue }
                if status == 401 { group.cancelAll(); logout(); loginError = "Your sign-in expired. Enter your PIN again."; continue }
                if status == 404 && ["mine", "team", "next"].contains(key) {
                    data[key] = .object(["schedule": .null]); errors[key] = nil
                } else if let payload {
                    if payload["fallback"].flag || payload["database_available"] == .bool(false) {
                        errors[key] = "HOP's database is temporarily unavailable. The last published schedule is shown if available."; continue
                    }
                    if key == "directory" { data[key] = .object(["employees": .array(payload["employees"].records.map { minimalIdentity($0).raw })]) }
                    else if key == "pending" || key == "history" { data[key] = safeRequestList(payload) }
                    else { data[key] = payload }
                    errors[key] = nil
                    if key == "profile" {
                        let updated = HOPRecord(payload["employee"])
                        if updated.status != "active" { group.cancelAll(); logout(); loginError = "This employee account is not active." }
                        else { employee = updated }
                    }
                } else { errors[key] = error ?? "Could not refresh. Pull down to try again." }
            }
        }
        guard generation == run else { return }
        loading = false; if errors.isEmpty { lastRefresh = Date() }
        if errors["mine"] == nil && errors["team"] == nil { ScheduleCache.write(employee: person.id, week: requestedWeek, sections: data) }
    }
    func changeWeek(_ days: Int) async { week = HOPCalendar.add(week, days: days); data = [:]; errors = [:]; loadSnapshot(); await refresh() }
    func selectWeek(_ value: String) async { guard HOPCalendar.date(value) != nil else { return }; week = HOPCalendar.tuesday(value); data = [:]; errors = [:]; loadSnapshot(); await refresh() }
    func clearScheduleCache() { if let employee { ScheduleCache.clear(employee: employee.id) }; message = "Saved schedule copies cleared from this iPhone. Live HOP records were not changed." }
    func refreshNotifications() async {
        guard let person = employee, !busy else { return }; let version = sessionVersion
        do {
            let result = try await api.request("/api/notifications/employee/\(person.id)")
            guard version == sessionVersion else { return }; data["notifications"] = result; errors["notifications"] = nil
        } catch let error as HOPAPIError where error.status == 401 { if version == sessionVersion { logout(); loginError = error.message } }
        catch { if version == sessionVersion { errors["notifications"] = error.localizedDescription } }
    }
    func act(_ path: String, body: [String: JSONValue] = [:], success: String) async -> Bool {
        guard !busy, let person = employee else { return false }; busy = true; defer { busy = false }
        let version = sessionVersion
        do {
            _ = try await api.request(path, method: "POST", body: .object(body))
            guard employee?.id == person.id, version == sessionVersion else { return false }
            message = success; await refresh(); return true
        } catch let error as HOPAPIError where error.status == 401 { if version == sessionVersion { logout(); loginError = error.message }; return false }
        catch { if version == sessionVersion { message = error is URLError ? "The connection ended before HOP confirmed the result. Refresh and check whether it was saved before submitting again." : error.localizedDescription }; return false }
    }
    private func named(_ shifts: [HOPShift]) -> [HOPShift] {
        shifts.map { shift in
            let known = records("directory", "employees").first { $0.id == shift.employeeID }?.name
            let name = known ?? (shift.employeeID == employee?.id ? employee?.name : nil) ?? (shift.employeeName.isEmpty ? "Name unavailable" : shift.employeeName)
            return shift.named(name)
        }
    }
    var shifts: [HOPShift] { named(HOPShift.from(data["mine"] ?? .null, week: week, employeeID: employee?.id)) }
    var teamShifts: [HOPShift] { named(HOPShift.from(data["team"] ?? .null, week: week)) }
    var futureShifts: [HOPShift] { (shifts + named(HOPShift.from(data["next"] ?? .null, week: HOPCalendar.add(week, days: 7), employeeID: employee?.id))).filter { ($0.endInstant ?? .distantPast) > Date() } }
    private func minimalIdentity(_ person: HOPRecord) -> HOPRecord {
        HOPRecord(.object(person.raw.fields.filter { ["id", "display_name", "name", "full_name", "role", "secondary_roles", "status"].contains($0.key) }))
    }
    private func safeRequestList(_ payload: JSONValue) -> JSONValue {
        // Legacy review payloads can contain a replacement PIN. Never retain it
        // in native state, logs, or the schedule-only disk cache.
        var object = payload.fields
        object["requests"] = .array(payload["requests"].records.map { record in
            var raw = record.raw.fields, p = record["payload"].fields, update = record["payload"]["profile_update"].fields
            update.removeValue(forKey: "pin"); update.removeValue(forKey: "password")
            if !update.isEmpty { p["profile_update"] = .object(update) }; raw["payload"] = .object(p)
            return .object(raw)
        }); return .object(object)
    }
    private func loadSnapshot() {
        guard let employee, let snapshot = ScheduleCache.read(employee: employee.id, week: week) else { return }
        data.merge(snapshot.sections) { _, snapshot in snapshot }
        for key in snapshot.sections.keys { errors[key] = "Saved on \(snapshot.savedAt.formatted(date: .abbreviated, time: .shortened)). Checking for a newer published version…" }
    }
    var notifications: [HOPRecord] { data["notifications"]?["notifications"].records ?? [] }
    var unread: Int { notifications.filter { !$0.isRead }.count }
    func records(_ section: String, _ key: String) -> [HOPRecord] { data[section]?[key].records ?? [] }
    func openNotification(_ record: HOPRecord) async {
        if !record.isRead { _ = await act("/api/notifications/\(record.id)/read", success: "Notification read") }
        screen = HOPLink.notification(record)
    }
}
