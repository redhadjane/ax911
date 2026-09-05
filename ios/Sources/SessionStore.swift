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
    private let scheduleProjection = HOPScheduleProjection()
    @Published var employee: HOPRecord? { didSet { prepareSchedule() } }
    @Published var screen: HOPLink = .home
    var presentedScreen: HOPLink?
    @Published var week = HOPCalendar.tuesday(HOPCalendar.today()) { didSet { prepareSchedule() } }
    @Published var data: [String: JSONValue] = [:] { didSet { prepareSchedule() } }
    @Published var errors: [String: String] = [:]
    @Published var loading = false
    @Published var busy = false
    @Published var message: String?
    @Published var loginError: String?
    @Published var lastRefresh: Date?
    private var generation = 0
    private var sessionVersion = 0
    private var expiry = Date.distantPast
    private var inFlight: [String: UUID] = [:]
    private var loadedAt: [String: Date] = [:]
    private(set) var endpointMilliseconds: [String: Double] = [:]
    private func prepareSchedule() { scheduleProjection.update(data: data, week: week, employee: employee) }
    private func setData(_ key: String, _ value: JSONValue) { if data[key] != value { data[key] = value } }
    private func setError(_ key: String, _ value: String?) { if errors[key] != value { errors[key] = value } }

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
        inFlight = [:]; loadedAt = [:]; endpointMilliseconds = [:]; presentedScreen = nil
        employee = nil; data = [:]; errors = [:]; expiry = .distantPast; loading = false; message = nil; lastRefresh = nil
        Task { await api.authorize("", version: version) }
    }
    func ensureLoaded(_ route: HOPLink) async { await refresh(sections: HOPRefreshPlan.sections(for: route), force: false) }
    func refresh(sections: Set<String>? = nil, force: Bool = true, supersede: Bool = false) async {
        guard let person = employee else { return }
        guard expiry > Date() else { logout(); loginError = "Your sign-in expired. Enter your PIN again."; return }
        let run = generation; let requestedWeek = week; let batch = UUID()
        let keys = sections ?? HOPRefreshPlan.sections(for: presentedScreen ?? screen)
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
        ].filter { key, _, _ in
            keys.contains(key) && (supersede || inFlight[key] == nil)
                && (force || data[key] == nil || errors[key] != nil || Date().timeIntervalSince(loadedAt[key] ?? .distantPast) > 30)
        }
        guard !endpoints.isEmpty else { return }
        for (key, _, _) in endpoints { inFlight[key] = batch }
        if !loading { loading = true }
        await withTaskGroup(of: (String, JSONValue?, String?, Int, Double).self) { group in
            for (key, path, query) in endpoints {
                group.addTask { [api] in
                    let started = ProcessInfo.processInfo.systemUptime
                    do { return (key, try await api.request(path, query: query), nil, 200, (ProcessInfo.processInfo.systemUptime - started) * 1000) }
                    catch let error as HOPAPIError { return (key, nil, error.message, error.status, (ProcessInfo.processInfo.systemUptime - started) * 1000) }
                    catch { return (key, nil, error.localizedDescription, 0, (ProcessInfo.processInfo.systemUptime - started) * 1000) }
                }
            }
            for await (key, payload, error, status, milliseconds) in group {
                guard generation == run, employee?.id == person.id, week == requestedWeek, inFlight[key] == batch else { continue }
                inFlight[key] = nil
                endpointMilliseconds[key] = milliseconds
                if status == 401 { group.cancelAll(); logout(); loginError = "Your sign-in expired. Enter your PIN again."; continue }
                if status == 404 && ["mine", "team", "next"].contains(key) {
                    setData(key, .object(["schedule": .null])); setError(key, nil); loadedAt[key] = Date()
                } else if let payload {
                    if payload["fallback"].flag || payload["database_available"] == .bool(false) {
                        setError(key, "HOP's database is temporarily unavailable. The last published schedule is shown if available."); continue
                    }
                    if key == "directory" { setData(key, .object(["employees": .array(payload["employees"].records.map { minimalIdentity($0).raw })])) }
                    else if key == "pending" || key == "history" { setData(key, safeRequestList(payload)) }
                    else { setData(key, payload) }
                    setError(key, nil); loadedAt[key] = Date()
                    if key == "profile" {
                        let updated = HOPRecord(payload["employee"])
                        if updated.status != "active" { group.cancelAll(); logout(); loginError = "This employee account is not active." }
                        else if employee != updated { employee = updated }
                    }
                } else { setError(key, error ?? "Could not refresh. Pull down to try again.") }
            }
        }
        guard generation == run else { return }
        for (key, _, _) in endpoints where inFlight[key] == batch { inFlight[key] = nil }
        let stillLoading = !inFlight.isEmpty; if loading != stillLoading { loading = stillLoading }
        if endpoints.allSatisfy({ errors[$0.0] == nil }) { lastRefresh = Date() }
        if !keys.isDisjoint(with: ["mine", "team", "next", "directory"]), errors["mine"] == nil, errors["team"] == nil {
            ScheduleCache.write(employee: person.id, week: requestedWeek, sections: data)
        }
    }
    func changeWeek(_ days: Int) async { await selectWeek(HOPCalendar.add(week, days: days)) }
    func selectWeek(_ value: String) async {
        guard HOPCalendar.date(value) != nil else { return }
        let selected = HOPCalendar.tuesday(value)
        if selected != week {
            generation += 1; inFlight = [:]; loading = false
            // Keep account-wide messages, requests and the name directory.
            data = data.filter { !HOPRefreshPlan.weekScoped.contains($0.key) }
            errors = errors.filter { !HOPRefreshPlan.weekScoped.contains($0.key) }
            loadedAt = loadedAt.filter { !HOPRefreshPlan.weekScoped.contains($0.key) }
            week = selected; loadSnapshot()
        }
        await refresh()
    }
    func clearScheduleCache() { if let employee { ScheduleCache.clear(employee: employee.id) }; message = "Saved schedule copies cleared from this iPhone. Live HOP records were not changed." }
    func refreshNotifications() async {
        guard !busy else { return }
        await refresh(sections: ["notifications"])
    }
    func act(_ path: String, body: [String: JSONValue] = [:], success: String) async -> Bool {
        guard !busy, let person = employee else { return false }; busy = true; defer { busy = false }
        let version = sessionVersion
        do {
            _ = try await api.request(path, method: "POST", body: .object(body))
            guard employee?.id == person.id, version == sessionVersion else { return false }
            message = success; await refresh(sections: HOPRefreshPlan.afterAction(path), supersede: true); return true
        } catch let error as HOPAPIError where error.status == 401 { if version == sessionVersion { logout(); loginError = error.message }; return false }
        catch { if version == sessionVersion { message = error is URLError ? "The connection ended before HOP confirmed the result. Refresh and check whether it was saved before submitting again." : error.localizedDescription }; return false }
    }
    var shifts: [HOPShift] { scheduleProjection.mine }
    var teamShifts: [HOPShift] { scheduleProjection.team }
    var futureShifts: [HOPShift] { (scheduleProjection.mine + scheduleProjection.next).filter { ($0.endInstant ?? .distantPast) > Date() } }
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
        screen = HOPLink.notification(record)
        if !record.isRead { _ = await act("/api/notifications/\(record.id)/read", success: "Notification read") }
    }
}
