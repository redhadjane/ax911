import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var store: HOPStore
    private var today: [HOPShift] { store.shifts.filter { $0.date == HOPCalendar.today() } }
    private var highlightedMessages: [HOPRecord] { let unread = Array(store.notifications.filter { !$0.isRead }.prefix(3)); return unread.isEmpty ? Array(store.notifications.prefix(2)) : unread }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(HOPCalendar.label(HOPCalendar.today(), format: "EEEE, MMMM d").uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text("Hi, \(store.employee?.name ?? "")").font(.largeTitle.bold())
                    }
                    Spacer(); EmployeeAvatar(url: store.employee?["profile_image_url"].text ?? "", name: store.employee?.name ?? "", size: 54)
                }
                if store.week != HOPCalendar.tuesday(HOPCalendar.today()) {
                    Button { Task { await store.selectWeek(HOPCalendar.today()) } } label: {
                        Label("Viewing another week · Return to today", systemImage: "arrow.uturn.backward")
                    }.buttonStyle(.bordered).controlSize(.large)
                }
                HOPError(section: "mine")
                if store.data["mine"] == nil && store.loading { ProgressView("Loading your published shifts…").frame(maxWidth: .infinity).padding(30) }
                else if store.data["mine"] != nil {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("TODAY AT HOP", systemImage: "sun.max").font(.caption.weight(.bold))
                        if today.isEmpty {
                            Text(store.week == HOPCalendar.tuesday(HOPCalendar.today()) ? "No published shift today" : "Viewing another week").font(.title.bold())
                            Text(store.week == HOPCalendar.tuesday(HOPCalendar.today()) ? "Check your next shift below, or open the team schedule." : "Return to the current week for today's shifts.").font(.subheadline)
                        } else {
                            ForEach(today) { shift in VStack(alignment: .leading, spacing: 5) { Text(shift.time).font(.title2.bold()); Text("\(shift.role) · \(shift.slot)").font(.headline) } }
                        }
                        Button { store.screen = .schedule } label: { Label("See schedule", systemImage: "arrow.right").font(.subheadline.weight(.semibold)) }.buttonStyle(.bordered).tint(.white)
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.white).background(HOPStyle.green, in: RoundedRectangle(cornerRadius: 26))
                }
                HOPError(section: "next")
                if let next = store.futureShifts.first(where: { ($0.startInstant ?? .distantPast) > Date() }) {
                    HOPSection(title: "Up next") { ShiftRow(shift: next, showEmployee: false, double: false) }
                }
                if store.data["mine"] != nil {
                    HOPSection(title: "Your week") {
                        HOPCard {
                            HStack {
                                MetricView(value: String(store.shifts.count), title: "Published shifts")
                                Spacer()
                                MetricView(value: String(format: "%.1f", Double(store.shifts.compactMap(\.minutes).reduce(0, +)) / 60), title: "Scheduled hours")
                            }
                            Text("\(HOPCalendar.label(store.week)) – \(HOPCalendar.label(HOPCalendar.add(store.week, days: 5)))").font(.caption).foregroundStyle(.secondary)
                            if store.shifts.contains(where: { $0.minutes == nil }) { Text("Some shift times are missing. Hours include only shifts with readable start and end times.").font(.caption).foregroundStyle(.orange) }
                        }
                    }
                }
                HOPSection(title: "Quick actions") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                        QuickAction(title: "Availability", icon: "calendar.badge.checkmark", route: .availability)
                        QuickAction(title: "My tasks", icon: "checklist", route: .tasks)
                        QuickAction(title: "Requests", icon: "arrow.left.arrow.right", route: .requests)
                        QuickAction(title: "HOP Club", icon: "qrcode.viewfinder", route: .club)
                    }
                }
                HOPError(section: "notifications")
                if !store.notifications.isEmpty {
                    HOPSection(title: store.unread > 0 ? "Needs your attention" : "Latest from HOP") {
                        ForEach(highlightedMessages) { record in
                            Button { Task { await store.openNotification(record) } } label: { NotificationRow(record: record) }.buttonStyle(.plain).disabled(store.busy)
                        }
                        Button("View all messages") { store.screen = .notifications }.frame(minHeight: 44)
                    }
                }
                if let refreshed = store.lastRefresh { Text("Last sync \(refreshed.formatted(date: .omitted, time: .shortened)) · Device local time").font(.caption).foregroundStyle(.secondary) }
            }.padding(20)
        }.background(HOPStyle.background).navigationTitle("HOP Staff").navigationBarTitleDisplayMode(.inline).refreshable { await store.refresh() }
    }
}

struct MetricView: View {
    let value: String; let title: String
    var body: some View { VStack(alignment: .leading, spacing: 4) { Text(value).font(.title.bold()); Text(title).font(.caption).foregroundStyle(.secondary) } }
}
struct QuickAction: View {
    @EnvironmentObject private var store: HOPStore
    let title: String; let icon: String; let route: HOPLink
    var body: some View { Button { HOPStyle.haptic(); store.screen = route } label: { HStack { Image(systemName: icon).font(.title3); Text(title).font(.subheadline.weight(.semibold)); Spacer(minLength: 0) }.padding(17).frame(maxWidth: .infinity, minHeight: 60).background(HOPStyle.surface, in: RoundedRectangle(cornerRadius: 18)) }.buttonStyle(.plain) }
}
struct EmployeeAvatar: View {
    @AppStorage("hopUsePhoto") private var usePhoto = true
    let url: String; let name: String; var size: CGFloat = 48
    var body: some View {
        Group {
            if !usePhoto { initials }
            else if url.hasPrefix("data:image"), let encoded = url.split(separator: ",").last, let data = Data(base64Encoded: String(encoded)), let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() }
            else if let remote = URL(string: url), remote.scheme == "https" { AsyncImage(url: remote) { image in image.resizable().scaledToFill() } placeholder: { initials } }
            else { initials }
        }.frame(width: size, height: size).clipShape(Circle()).accessibilityLabel(name)
    }
    private var initials: some View { Text(name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()).font(.headline).frame(maxWidth: .infinity, maxHeight: .infinity).background(HOPStyle.green.opacity(0.13)) }
}

struct ScheduleView: View {
    @EnvironmentObject private var store: HOPStore
    @State private var team = false
    @State private var role = "all"
    @State private var selected: HOPShift?
    @State private var share: ShareDocument?
    @State private var showSwap = false
    @AppStorage("hopScheduleMode") private var mode = "agenda"
    @State private var selectedDay = ""
    private var matching: [HOPShift] { (team ? store.teamShifts : store.shifts).filter { role == "all" || $0.roleKey == role } }
    private var visible: [HOPShift] { matching.filter { mode != "day" || $0.date == selectedDay } }
    private var days: [String] { Array(Set(visible.map(\.date))).sorted() }
    var body: some View {
        let schedule = team ? store.teamShifts : store.shifts
        let matching = schedule.filter { role == "all" || $0.roleKey == role }
        let visible = matching.filter { mode != "day" || $0.date == selectedDay }
        let groups = Dictionary(grouping: visible, by: \.date)
        let counts = Dictionary(grouping: schedule, by: { $0.date + "|" + $0.employeeID }).mapValues(\.count)
        ScrollView {
            LazyVStack(spacing: 18) {
                WeekControl()
                Picker("Schedule", selection: $team) { Text("My shifts").tag(false); Text("Everyone").tag(true) }.pickerStyle(.segmented)
                Picker("Role", selection: $role) { Text("All roles").tag("all"); Text("Serving").tag("main"); Text("Hosting").tag("host"); Text("Floor help").tag("support") }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                Picker("Layout", selection: $mode) { Text("Week agenda").tag("agenda"); Text("By day").tag("day") }.pickerStyle(.segmented)
                if mode == "day" {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(0..<6) { offset in
                                let day = HOPCalendar.add(store.week, days: offset)
                                Button { selectedDay = day; HOPStyle.haptic() } label: {
                                    VStack(spacing: 5) { Text(HOPCalendar.label(day, format: "EEE")).font(.caption); Text(HOPCalendar.label(day, format: "d")).font(.headline); Text("\(matching.filter { $0.date == day }.count)").font(.caption2) }.frame(width: 58, height: 80).background(selectedDay == day ? HOPStyle.green : HOPStyle.surface, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(selectedDay == day ? Color.white : Color.primary)
                                }.buttonStyle(.plain).accessibilityLabel("\(HOPCalendar.label(day)), \(matching.filter { $0.date == day }.count) shifts")
                            }
                        }
                    }.scrollIndicators(.hidden)
                }
                HOPError(section: team ? "team" : "mine")
                if team { HOPError(section: "directory") }
                if store.loading && store.data[team ? "team" : "mine"] == nil { ProgressView("Loading published schedule…").padding(36) }
                else if visible.isEmpty && store.errors[team ? "team" : "mine"] == nil { HOPEmpty(title: "No published shifts", detail: "There are no published assignments for this view. Draft changes stay private until your manager publishes them.", icon: "calendar") }
                ForEach(groups.keys.sorted(), id: \.self) { day in
                    HOPSection(title: HOPCalendar.label(day, format: "EEEE, MMM d")) {
                        ForEach(groups[day] ?? []) { shift in
                            Button { selected = shift; HOPStyle.haptic() } label: {
                                ShiftRow(shift: shift, showEmployee: team, double: (counts[day + "|" + shift.employeeID] ?? 0) > 1)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Text("Times are shown in Gaffney time (Eastern), including when you travel.").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.background(HOPStyle.background).navigationTitle("Schedule").refreshable { await store.refresh() }
        .onAppear { if selectedDay.isEmpty { selectedDay = HOPCalendar.tuesday(HOPCalendar.today()) == store.week && HOPCalendar.today() <= HOPCalendar.add(store.week, days: 5) ? HOPCalendar.today() : store.week } }
        .onChange(of: store.week) { _, key in selectedDay = key }
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Share printable PDF", systemImage: "doc.richtext") { export("pdf") }
                Button("Share schedule image", systemImage: "photo") { export("png") }
                Button("Export my shifts (.ics)", systemImage: "calendar.badge.plus") { export("ics") }
            } label: { Image(systemName: "square.and.arrow.up") }.disabled(visible.isEmpty)
        } }
        .sheet(item: $share) { ShareSheet(items: [$0.url]) }
        .sheet(item: $selected) { shift in
            NavigationStack {
                List {
                    Section(HOPCalendar.label(shift.date, format: "EEEE, MMMM d")) {
                        Text(shift.time).font(.title2.bold()); Label(shift.role, systemImage: "person.text.rectangle"); LabeledContent("Shift", value: shift.slot)
                        if team { LabeledContent("Employee", value: shift.employeeName) }
                    }
                    if shift.employeeID == store.employee?.id {
                        Section {
                            Button("Request a shift switch", systemImage: "arrow.left.arrow.right") { showSwap = true }
                            Button("View shift tasks", systemImage: "checklist") { selected = nil; store.screen = .tasks }
                        } footer: { Text("A switch is not final until the other employee accepts and a manager approves.") }
                    }
                }.navigationTitle("Shift details").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { selected = nil } } }
                .sheet(isPresented: $showSwap) { NavigationStack { ShiftSwitchView(initialShiftID: shift.id) } }
            }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
    }
    private func export(_ format: String) {
        do {
            let shifts = format == "ics" ? store.shifts : visible
            let data = format == "ics" ? Data(HOPExport.calendar(shifts).utf8) : NativeScheduleExport.render(shifts, week: store.week, title: team ? "Team schedule" : "My shifts", png: format == "png")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("HOP-\(UUID().uuidString).\(format)")
            try data.write(to: url, options: .atomic); share = ShareDocument(url: url)
        } catch { store.message = "Could not prepare your export: \(error.localizedDescription)" }
    }
}
struct ShiftRow: View {
    let shift: HOPShift; let showEmployee: Bool; let double: Bool
    var body: some View {
        HOPCard {
            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 3).fill(shift.roleKey == "host" ? Color.blue : shift.roleKey == "support" ? Color.orange : HOPStyle.green).frame(width: 4)
                VStack(alignment: .leading, spacing: 6) {
                    if showEmployee { Text(shift.employeeName).font(.headline) }
                    Text(shift.time).font(showEmployee ? .subheadline.weight(.semibold) : .headline)
                    Text("\(shift.role) · \(shift.slot)").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if double { Text("×2").font(.caption.bold()).padding(7).background(Color.blue.opacity(0.12), in: Capsule()).accessibilityLabel("Multiple shifts this day") }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }.fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct NotificationsView: View {
    @EnvironmentObject private var store: HOPStore
    @State private var onlyUnread = false
    @State private var selected: HOPRecord?
    @State private var category = "all"
    private var records: [HOPRecord] { store.notifications.filter { (!onlyUnread || !$0.isRead) && (category == "all" || $0["category"].text == category) } }
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                Toggle("Unread only", isOn: $onlyUnread).padding(.horizontal, 4)
                Picker("Message type", selection: $category) { Text("All messages").tag("all"); ForEach(Array(Set(store.notifications.map { $0["category"].text })).filter { !$0.isEmpty }.sorted(), id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0) } }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                HOPError(section: "notifications")
                if store.loading && store.data["notifications"] == nil { ProgressView("Loading messages…") }
                else if records.isEmpty && store.errors["notifications"] == nil { HOPEmpty(title: "You're caught up", detail: "Announcements and request decisions appear here.", icon: "bell.badge") }
                ForEach(records) { record in Button { selected = record } label: { NotificationRow(record: record) }.buttonStyle(.plain) }
                Text("Messages refresh while HOP is open. iPhone background push is not enabled in this build.").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.background(HOPStyle.background).navigationTitle("Inbox").refreshable { await store.refresh() }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Read all") { Task { _ = await store.act("/api/notifications/employee/\(store.employee?.id ?? "")/read-all", success: "Messages marked as read.") } }.disabled(store.busy || store.unread == 0) } }
        .sheet(item: $selected) { record in
            NavigationStack {
                ScrollView { VStack(alignment: .leading, spacing: 20) {
                    Text(record.title).font(.title2.bold()); Text(record["message"].text).font(.body).textSelection(.enabled)
                    Text(record["created_at"].text).font(.caption).foregroundStyle(.secondary)
                    if !record.isRead { Button("Mark as read", systemImage: "checkmark") { Task { if await store.act("/api/notifications/\(record.id)/read", success: "Notification marked as read.") { selected = nil } } }.buttonStyle(.bordered).disabled(store.busy) }
                    if HOPLink.notification(record) != .notifications { Button("Open related \(HOPLink.notification(record).rawValue)", systemImage: "arrow.up.right") { Task { selected = nil; await store.openNotification(record) } }.buttonStyle(.borderedProminent).controlSize(.large).disabled(store.busy) }
                }.padding(24) }.navigationTitle("Message").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { selected = nil } } }
            }.presentationDetents([.medium, .large])
        }
    }
}
struct NotificationRow: View {
    let record: HOPRecord
    var body: some View {
        HOPCard { HStack(alignment: .top, spacing: 12) {
            Image(systemName: record.isRead ? "envelope.open" : "envelope.badge").font(.title3).foregroundStyle(HOPStyle.green).frame(width: 30)
            VStack(alignment: .leading, spacing: 6) { Text(record.title).font(.headline); Text(record["message"].text).font(.subheadline).foregroundStyle(.secondary).lineLimit(3) }
            Spacer(minLength: 0)
            if !record.isRead { Circle().fill(HOPStyle.green).frame(width: 8, height: 8).accessibilityLabel("Unread") }
        } }
    }
}

struct TasksView: View {
    @EnvironmentObject private var store: HOPStore
    @State private var showDone = true
    private var assignments: [HOPRecord] { store.records("tasks", "assignments").filter { showDone || !$0["completed"].flag } }
    var body: some View {
        ScrollView { LazyVStack(spacing: 16) {
            WeekControl(); Toggle("Show completed tasks", isOn: $showDone); HOPError(section: "tasks")
            if store.loading && store.data["tasks"] == nil { ProgressView("Loading your assigned tasks…") }
            else if assignments.isEmpty && store.errors["tasks"] == nil { HOPEmpty(title: "No tasks in this view", detail: "Tasks follow your published shift assignments. Your manager can add tasks to a shift.", icon: "checklist") }
            ForEach(assignments) { task in
                HOPCard {
                    HStack(alignment: .top, spacing: 14) {
                        Button { Task { await toggle(task) } } label: { Image(systemName: task["completed"].flag ? "checkmark.circle.fill" : "circle").font(.title).frame(width: 44, height: 44) }.disabled(store.busy).accessibilityLabel(task["completed"].flag ? "Reopen \(task.title)" : "Complete \(task.title)")
                        VStack(alignment: .leading, spacing: 6) {
                            Text(task.title).font(.headline).strikethrough(task["completed"].flag)
                            Text("\(HOPCalendar.label(task["task_date"].text)) · \(task.first("role_label", "row_label", "assignment_label"))").font(.subheadline).foregroundStyle(.secondary)
                            Text("\(HOPCalendar.clock(task["start_time"].text)) – \(HOPCalendar.clock(task["end_time"].text))").font(.caption).foregroundStyle(.secondary)
                            if !task["area"].text.isEmpty { Label(task["area"].text, systemImage: "mappin").font(.caption) }
                            if !task["notes"].text.isEmpty { Text(task["notes"].text).font(.subheadline) }
                        }
                    }
                }
            }
        }.padding(20) }.background(HOPStyle.background).navigationTitle("My tasks").refreshable { await store.refresh() }
    }
    private func toggle(_ task: HOPRecord) async {
        let done = !task["completed"].flag
        let okay = await store.act("/api/tasks/complete", body: ["employee_id": .string(store.employee?.id ?? ""), "task_id": task["task_id"], "schedule_entry_id": task["schedule_entry_id"], "task_date": .string(String(task["task_date"].text.prefix(10))), "done": .bool(done)], success: done ? "Task completed." : "Task reopened.")
        if okay { HOPStyle.haptic() }
    }
}

struct PartiesView: View {
    @EnvironmentObject private var store: HOPStore
    var body: some View {
        ScrollView { LazyVStack(spacing: 18) {
            WeekControl(); HOPError(section: "parties")
            if store.loading && store.data["parties"] == nil { ProgressView("Loading parties…") }
            else if store.records("parties", "parties").isEmpty && store.errors["parties"] == nil { HOPEmpty(title: "No parties listed", detail: "Published party bookings for this week will appear here.", icon: "person.3") }
            ForEach(store.records("parties", "parties").sorted { $0["date"].text + $0["time"].text < $1["date"].text + $1["time"].text }) { party in
                HOPCard { Text(party.name).font(.title3.bold()); Label("\(HOPCalendar.label(party["date"].text)) · \(HOPCalendar.clock(party["time"].text))", systemImage: "calendar"); Text("\(party["count"].text) guests · \(party["area"].text)").foregroundStyle(.secondary); HOPStatus(value: party.status)
                    if !party["assigned_waitress_name"].text.isEmpty { LabeledContent("Assigned server", value: party["assigned_waitress_name"].text) }
                    if !party["notes"].text.isEmpty { Text(party["notes"].text).font(.subheadline) }
                }
            }
        }.padding(20) }.background(HOPStyle.background).navigationTitle("Parties").refreshable { await store.refresh() }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var store: HOPStore
    @AppStorage("hopAppearance") private var appearance = "system"
    @AppStorage("hopHaptics") private var haptics = true
    @AppStorage("hopUsePhoto") private var usePhoto = true
    @State private var edit = false
    @State private var signOut = false
    var body: some View {
        List {
            Section {
                HStack(spacing: 16) { EmployeeAvatar(url: store.employee?["profile_image_url"].text ?? "", name: store.employee?.name ?? "", size: 66); VStack(alignment: .leading, spacing: 5) { Text(store.employee?.name ?? "").font(.title2.bold()); Text(store.employee?["role"].text.capitalized ?? "").foregroundStyle(.secondary) } }.padding(.vertical, 12)
                if let person = store.employee {
                    if !person["phone"].text.isEmpty { LabeledContent("Phone", value: person["phone"].text) }
                    if !person["secondary_roles"].values.isEmpty { LabeledContent("Additional roles", value: person["secondary_roles"].values.map(\.text).joined(separator: ", ")) }
                    if !person.first("standing", "manager_rating", "rank", "performance_status").isEmpty { LabeledContent("Standing", value: person.first("standing", "manager_rating", "rank", "performance_status")) }
                    if !person.first("late_marks", "late_count").isEmpty { LabeledContent("Late marks", value: person.first("late_marks", "late_count")) }
                    if !person.first("behavior_marks", "unaccepted_marks", "incident_marks").isEmpty { LabeledContent("Other marks", value: person.first("behavior_marks", "unaccepted_marks", "incident_marks")) }
                }
                Button("Request profile or PIN change", systemImage: "person.crop.circle.badge.pencil") { edit = true }
            } footer: { Text("Profile, photo and PIN changes are reviewed by your manager. Your current PIN is never downloaded or displayed.") }
            Section("Your work") {
                Button("Availability", systemImage: "calendar.badge.checkmark") { store.screen = .availability }
                Button("Shift tasks", systemImage: "checklist") { store.screen = .tasks }
                Button("Parties this week", systemImage: "person.3") { store.screen = .parties }
                Button("HOP Club scanner", systemImage: "qrcode.viewfinder") { store.screen = .club }
            }
            Section("On this iPhone") {
                Picker("Appearance", selection: $appearance) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }
                Toggle("Touch feedback", isOn: $haptics)
                Toggle("Use profile photos", isOn: $usePhoto)
                LabeledContent("Schedule timezone", value: "Eastern / Gaffney")
            }
            Section("Connection") {
                HOPError(section: "profile")
                Button("Refresh HOP data", systemImage: "arrow.clockwise") { Task { await store.refresh(sections: HOPRefreshPlan.all) } }.disabled(store.loading)
                Button("Clear saved schedule copies", systemImage: "externaldrive.badge.minus") { store.clearScheduleCache() }.disabled(store.loading)
                DisclosureGroup("Connection details") {
                    ForEach(["mine", "team", "availability", "pending", "history", "swaps", "notifications", "tasks", "parties", "profile"], id: \.self) { key in
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent(key == "mine" ? "My schedule" : key.capitalized, value: store.errors[key] != nil ? "Needs attention" : store.data[key] == nil ? "Loads when opened" : "Loaded")
                            if let elapsed = store.endpointMilliseconds[key] { Text(String(format: "Last request %.0f ms", elapsed)).font(.caption).foregroundStyle(.secondary) }
                            if let error = store.errors[key] { Text(error).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                Text("This app reads the existing HOP system. Draft schedules remain private. Notification feeds refresh in the foreground; native background push requires a later server and signing update.").font(.footnote).foregroundStyle(.secondary)
            }
            Section { Button("Sign out", role: .destructive) { signOut = true } }
            Section { LabeledContent("Version", value: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))") }
        }.navigationTitle("Me").sheet(isPresented: $edit) { NavigationStack { ProfileRequestView() } }
        .confirmationDialog("Sign out of HOP on this iPhone?", isPresented: $signOut, titleVisibility: .visible) { Button("Sign out", role: .destructive) { store.logout() } }
    }
}

struct ShareDocument: Identifiable { let id = UUID(); let url: URL }
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Native vector PDF with repeated headers and page breaks. PNG uses a taller
// canvas so every visible shift is included; neither path screenshots the UI.
@MainActor enum NativeScheduleExport {
    static func render(_ shifts: [HOPShift], week: String, title: String, png: Bool) -> Data {
        let width: CGFloat = 612, pageHeight: CGFloat = 792
        let ink = UIColor.label.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let green = UIColor(red: 0.04, green: 0.30, blue: 0.23, alpha: 1)
        func text(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat, size: CGFloat, bold: Bool = false, color: UIColor? = nil) {
            (text as NSString).draw(in: CGRect(x: x, y: y, width: w, height: 45), withAttributes: [.font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size), .foregroundColor: color ?? ink])
        }
        func header(_ context: CGContext) {
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: width, height: png ? max(pageHeight, CGFloat(shifts.count * 62 + 150)) : pageHeight))
            green.setFill(); context.fill(CGRect(x: 28, y: 28, width: 556, height: 72))
            text("HOUSE OF PIZZA & PASTA", x: 44, y: 40, w: 520, size: 12, bold: true, color: .white)
            text(title, x: 44, y: 60, w: 520, size: 23, bold: true, color: .white)
            text("Week of \(HOPCalendar.label(week)) · Published shifts · Eastern time", x: 28, y: 108, w: 556, size: 10)
        }
        func row(_ shift: HOPShift, y: CGFloat, context: CGContext) {
            UIColor(white: 0.96, alpha: 1).setFill(); context.fill(CGRect(x: 28, y: y, width: 556, height: 56))
            text(HOPCalendar.label(shift.date), x: 38, y: y + 8, w: 112, size: 11, bold: true)
            text(shift.employeeName, x: 150, y: y + 8, w: 225, size: 13, bold: true)
            text("\(shift.role) · \(shift.slot)", x: 150, y: y + 29, w: 225, size: 10)
            text(shift.time, x: 377, y: y + 15, w: 195, size: 11)
        }
        if png {
            let size = CGSize(width: width, height: max(pageHeight, CGFloat(shifts.count * 62 + 150)))
            let format = UIGraphicsImageRendererFormat(); format.scale = 2; format.opaque = true
            return UIGraphicsImageRenderer(size: size, format: format).pngData { ctx in header(ctx.cgContext); for (i, shift) in shifts.enumerated() { row(shift, y: 138 + CGFloat(i) * 62, context: ctx.cgContext) } }
        }
        return UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: width, height: pageHeight)).pdfData { ctx in
            ctx.beginPage(); header(ctx.cgContext); var y: CGFloat = 138
            for shift in shifts {
                if y + 62 > pageHeight - 30 { ctx.beginPage(); header(ctx.cgContext); y = 138 }
                row(shift, y: y, context: ctx.cgContext); y += 62
            }
        }
    }
}
