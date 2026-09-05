import SwiftUI
import UIKit
import UserNotifications
import AudioToolbox

struct TeamWeekBoard: View {
    let shifts: [HOPShift]
    let allShifts: [HOPShift]
    let week: String
    let employeeID: String
    let select: (HOPShift) -> Void
    var body: some View {
        let board = HOPTeamBoard(shifts: shifts, allShifts: allShifts)
        VStack(alignment: .leading, spacing: 12) {
            Label("\(board.employees.count) people · \(shifts.count) published shifts", systemImage: "person.3").font(.subheadline.weight(.semibold))
            Text("Swipe across for the full week. Tap a shift for details. A dash means no published assignment—not confirmed time off.").font(.caption).foregroundStyle(.secondary)
            // One scroll container keeps names, dates and double shifts aligned,
            // including when Dynamic Type increases individual row heights.
            ScrollView(.horizontal) {
                Grid(alignment: .topLeading, horizontalSpacing: 6, verticalSpacing: 8) {
                    GridRow {
                        Text("TEAM").font(.caption.bold()).frame(width: 96, alignment: .leading)
                        ForEach(0..<6) { offset in
                            let date = HOPCalendar.add(week, days: offset)
                            VStack(spacing: 5) { Text(HOPCalendar.label(date, format: "EEE").uppercased()).font(.caption.bold()); Text(HOPCalendar.label(date, format: "MMM d")).font(.subheadline.weight(.semibold)) }.frame(width: 145).padding(.vertical, 10).background(date == HOPCalendar.today() ? HOPStyle.green.opacity(0.14) : HOPStyle.paper, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    ForEach(board.employees, id: \.employeeID) { person in
                        GridRow {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(person.employeeName).font(.subheadline.bold())
                                if person.employeeID == employeeID { Text("YOU").font(.caption2.bold()).foregroundStyle(HOPStyle.green) }
                            }.frame(width: 96, alignment: .leading).padding(.top, 10)
                            ForEach(0..<6) { offset in
                                let key = person.employeeID + "|" + HOPCalendar.add(week, days: offset)
                                VStack(spacing: 6) {
                                    if (board.cells[key] ?? []).isEmpty { Text("—").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 76).accessibilityLabel("\(person.employeeName), \(HOPCalendar.label(HOPCalendar.add(week, days: offset))), no published shift") }
                                    ForEach(board.cells[key] ?? []) { shift in
                                        Button { select(shift) } label: {
                                            VStack(alignment: .leading, spacing: 6) {
                                                HStack { Text(shift.role).font(.caption.bold()); Spacer(minLength: 0); if (board.doubleCounts[key] ?? 0) > 1 { Text("×\(board.doubleCounts[key] ?? 0)").font(.caption2.bold()).padding(4).background(HOPStyle.green.opacity(0.12), in: Capsule()) } }
                                                Text(shift.time).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                                                Text(shift.slot).font(.caption).foregroundStyle(.secondary)
                                            }.padding(10).frame(maxWidth: .infinity, minHeight: 76, alignment: .leading).background(HOPStyle.surface, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(HOPStyle.border))
                                        }.buttonStyle(.plain).accessibilityLabel("\(person.employeeName), \(HOPCalendar.label(shift.date)), \(shift.role), \(shift.time). Shift details")
                                    }
                                }.frame(width: 145)
                            }
                        }
                    }
                }.padding(12)
            }.background(HOPStyle.paper, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

struct TodayWorkSummary: View {
    @EnvironmentObject private var store: HOPStore
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if store.week == HOPCalendar.tuesday(HOPCalendar.today()) { HOPSection(title: "Around your shift") {
                HOPError(section: "tasks")
                if store.data["tasks"] != nil {
                    let tasks = store.records("tasks", "assignments").filter { !$0["completed"].flag && String($0["task_date"].text.prefix(10)) == HOPCalendar.today() }
                    Button { store.taskShiftID = nil; store.screen = .tasks } label: {
                        HOPCard { Label("\(tasks.count) unfinished tasks today", systemImage: "checklist").font(.headline); Text(tasks.isEmpty ? "Open your weekly task list" : tasks.prefix(2).map(\.title).joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary) }
                    }.buttonStyle(.plain)
                }
                HOPError(section: "parties")
                if store.data["parties"] != nil {
                    let parties = store.records("parties", "parties").filter { String($0["date"].text.prefix(10)) == HOPCalendar.today() }
                    Button { store.screen = .parties } label: {
                        HOPCard { Label("\(parties.count) parties today", systemImage: "person.3").font(.headline); Text(parties.isEmpty ? "View bookings for the selected week" : parties.prefix(2).map { "\(HOPCalendar.clock($0["time"].text)) · \($0.name)" }.joined(separator: "\n")).font(.subheadline).foregroundStyle(.secondary) }
                    }.buttonStyle(.plain)
                }
                if store.data["tasks"] == nil && store.data["parties"] == nil { Text("Loading shift tasks and party bookings…").font(.caption).foregroundStyle(.secondary) }
            } }
        }
        // Defer secondary home feeds until this section appears. The four-feed
        // startup/performance path remains unchanged.
        .task(id: store.week) { if store.week == HOPCalendar.tuesday(HOPCalendar.today()) { await store.refresh(sections: ["tasks", "parties"], force: false) } }
    }
}

struct ReminderDestination: Identifiable { let id = UUID(); let employeeID: String; let date: String; let shiftID: String }

@MainActor final class HOPDeviceAlerts: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = HOPDeviceAlerts()
    @Published var authorization = "Checking…"
    @Published var pendingCount = 0
    @Published var status = "Reminders are off until you enable them."
    @Published var destination: ReminderDestination?
    private let center = UNUserNotificationCenter.current()
    private var operation: Task<Void, Never>?
    private var account = ""
    private var epoch = 0
    private override init() { super.init(); center.delegate = self }
    func setEmployee(_ id: String) {
        guard account != id else { return }
        let sameRestoredAccount = account.isEmpty && !id.isEmpty && UserDefaults.standard.string(forKey: "hopReminderAccount") == id
        account = id; epoch += 1
        UserDefaults.standard.set(id, forKey: "hopReminderAccount")
        if !sameRestoredAccount { if destination?.employeeID != id { destination = nil }; clear() }
    }
    func clear() {
        let previous = operation
        operation = Task { await previous?.value; center.removeAllPendingNotificationRequests(); center.removeAllDeliveredNotifications(); pendingCount = 0 }
    }
    func inspect() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: authorization = "Allowed"
        case .denied: authorization = "Off in iPhone Settings"
        case .notDetermined: authorization = "Not requested"
        @unknown default: authorization = "Unknown"
        }
        pendingCount = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("hop-shift-") }.count
    }
    func requestPermission() async {
        do { let granted = try await center.requestAuthorization(options: [.alert, .sound]); status = granted ? "Permission granted. Enable shift reminders below." : "Notifications are disabled in iPhone Settings." }
        catch { status = error.localizedDescription }
        await inspect()
    }
    func test() async {
        await inspect(); guard authorization == "Allowed" else { status = "Allow notifications first."; return }
        let content = UNMutableNotificationContent(); content.title = "HOP reminder test"; content.body = "Local iPhone test—not a server push."
        if UserDefaults.standard.object(forKey: "hopAlertSound") as? Bool != false { content.sound = .default }
        do { try await center.add(UNNotificationRequest(identifier: "hop-local-test", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false))); status = "Local test scheduled in 3 seconds." }
        catch { status = error.localizedDescription }
    }
    func synchronize(shifts: [HOPShift], employeeID: String, week: String, expires: Date) async {
        let previous = operation, version = epoch
        operation = Task {
            await previous?.value
            guard account == employeeID, epoch == version else { return }
            let prefix = "hop-shift-\(employeeID)-\(week)-"
            let pending = await center.pendingNotificationRequests()
            guard account == employeeID, epoch == version else { return }
            center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier))
            let prefs = UserDefaults.standard
            guard prefs.bool(forKey: "hopShiftReminders") else { center.removeAllPendingNotificationRequests(); pendingCount = 0; return }
            let permission = await center.notificationSettings()
            guard [.authorized, .provisional, .ephemeral].contains(permission.authorizationStatus), account == employeeID, epoch == version else { return }
            let lead = prefs.object(forKey: "hopReminderLead") as? Int ?? 60
            let now = Date(), remaining = max(0, 60 - pending.filter { !$0.identifier.hasPrefix(prefix) }.count)
            var count = 0
            for shift in shifts.sorted(by: { ($0.startInstant ?? .distantFuture) < ($1.startInstant ?? .distantFuture) }) {
                guard count < remaining, account == employeeID, epoch == version else { break }
                guard let fire = HOPAlertPolicy.reminderDate(shift, employeeID: employeeID, lead: lead, now: now, expires: expires, quietEnabled: prefs.bool(forKey: "hopQuietHours"), quietStart: prefs.object(forKey: "hopQuietStart") as? Int ?? 1320, quietEnd: prefs.object(forKey: "hopQuietEnd") as? Int ?? 420) else { continue }
                let content = UNMutableNotificationContent(); content.title = "Your HOP shift starts in \(lead) minutes"
                content.body = prefs.object(forKey: "hopAlertPreview") as? Bool == false ? "Open HOP to view your shift." : "\(shift.role) · \(shift.time)"
                if prefs.object(forKey: "hopAlertSound") as? Bool != false { content.sound = .default }
                content.userInfo = ["employee_id": employeeID, "date": shift.date, "shift_id": shift.id]
                var components = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: fire)
                components.calendar = Calendar(identifier: .gregorian); components.timeZone = TimeZone(secondsFromGMT: 0)
                do { try await center.add(UNNotificationRequest(identifier: prefix + shift.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))); count += 1 }
                catch { status = "Could not schedule a reminder: \(error.localizedDescription)" }
            }
            pendingCount = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("hop-shift-") }.count
            status = "\(pendingCount) reminders scheduled from the latest schedules loaded on this iPhone."
        }
        await operation?.value
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { completionHandler([.banner, .sound]) }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let payload = response.notification.request.content.userInfo
        let id = payload["employee_id"] as? String ?? "", date = payload["date"] as? String ?? "", shift = payload["shift_id"] as? String ?? ""
        Task { @MainActor in
            if !id.isEmpty, HOPCalendar.date(date) != nil, !shift.isEmpty { self.destination = ReminderDestination(employeeID: id, date: date, shiftID: shift) }
            completionHandler()
        }
    }
}

struct AlertSettingsView: View {
    @EnvironmentObject private var store: HOPStore
    @ObservedObject private var alerts = HOPDeviceAlerts.shared
    @AppStorage("hopShiftReminders") private var reminders = false
    @AppStorage("hopReminderLead") private var lead = 60
    @AppStorage("hopAlertSound") private var sound = true
    @AppStorage("hopAlertPreview") private var previews = true
    @AppStorage("hopForegroundAlerts") private var banners = true
    @AppStorage("hopQuietHours") private var quiet = false
    @AppStorage("hopQuietStart") private var quietStart = 1320
    @AppStorage("hopQuietEnd") private var quietEnd = 420
    @AppStorage("hopAlertSchedule") private var schedule = true
    @AppStorage("hopAlertRequests") private var requests = true
    @AppStorage("hopAlertTasks") private var tasks = true
    @AppStorage("hopAlertParties") private var parties = true
    @AppStorage("hopAlertOther") private var other = true
    var body: some View {
        Form {
            Section("Delivery status") {
                LabeledContent("iPhone permission", value: alerts.authorization)
                LabeledContent("Server background push", value: "Not configured")
                LabeledContent("Scheduled local reminders", value: String(alerts.pendingCount))
                Button("Allow iPhone notifications") { Task { await alerts.requestPermission() } }
                Button("Open iPhone notification settings") { if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) } }
                Button("Test local notification") { Task { await alerts.test() } }
                Text(alerts.status).font(.footnote).foregroundStyle(.secondary)
            } footer: { Text("Background server push needs an Apple push-enabled signing profile and HOP server setup. The local test does not verify server delivery.") }
            Section("Shift reminders on this iPhone") {
                Toggle("Remind me before my shift", isOn: $reminders)
                Picker("Remind me", selection: $lead) { ForEach([15,30,60,120], id: \.self) { Text("\($0) minutes before").tag($0) } }.disabled(!reminders)
                Toggle("Play sound", isOn: $sound)
                Toggle("Show shift details in alerts", isOn: $previews)
            } footer: { Text("Only your published shifts are eligible. Reminders use Gaffney time and the schedules last loaded here. Open HOP after schedule changes; remote changes cannot update local reminders while HOP is closed. Reminders stop at session expiry.") }
            Section("While HOP is open") {
                Toggle("Show new-message banners", isOn: $banners)
                Toggle("Schedule updates", isOn: $schedule)
                Toggle("Requests and shift switches", isOn: $requests)
                Toggle("Tasks", isOn: $tasks)
                Toggle("Parties", isOn: $parties)
                Toggle("Announcements and other messages", isOn: $other)
            } footer: { Text("These filters control in-app banners only. All messages remain in your Inbox.") }
            Section("Quiet hours · Gaffney time") {
                Toggle("Use quiet hours", isOn: $quiet)
                Picker("Start", selection: $quietStart) { ForEach(0..<24) { Text(HOPCalendar.clock(String(format: "%02d:00", $0))).tag($0 * 60) } }.disabled(!quiet)
                Picker("End", selection: $quietEnd) { ForEach(0..<24) { Text(HOPCalendar.clock(String(format: "%02d:00", $0))).tag($0 * 60) } }.disabled(!quiet)
            } footer: { Text("Local reminders and in-app banners in this window are skipped, not delayed. Equal start and end means no quiet window. Your iPhone Focus settings also apply.") }
            Section { Button("Apply reminder settings") { Task { await store.rescheduleReminders(); await alerts.inspect() } }.disabled(store.loading) }
        }.scrollContentBackground(.hidden).background(HOPStyle.background).navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline)
        .task { await alerts.inspect() }
        .onChange(of: reminders) { _, enabled in if !enabled { alerts.clear() } }
        .onDisappear { Task { await store.rescheduleReminders() } }
    }
}
