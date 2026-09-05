import SwiftUI
import UIKit

@main struct HOPEmployeeApp: App {
    @StateObject private var store = HOPStore()
    @AppStorage("hopAppearance") private var appearance = "system"
    var body: some Scene {
        WindowGroup {
            HOPRoot().environmentObject(store)
                .tint(HOPStyle.green)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        }
    }
}

enum HOPStyle {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
    static let green = adaptive(0x0F5B4C, 0x71C7AF)
    static let hero = Color(red: 15/255, green: 91/255, blue: 76/255)
    static let secondaryGreen = adaptive(0x0B7A63, 0x87D7BE)
    static let warm = adaptive(0xFFFBF2, 0x20352E)
    static let background = adaptive(0xF5F2EA, 0x10241F)
    static let surface = adaptive(0xFFFFFF, 0x19332B)
    static let paper = adaptive(0xFFFDF7, 0x203B32)
    static let border = adaptive(0xE8DFCF, 0x365348)
    @MainActor static func haptic() { if UserDefaults.standard.object(forKey: "hopHaptics") as? Bool != false { UISelectionFeedbackGenerator().selectionChanged() } }
}

extension HOPLink: Identifiable { public var id: String { rawValue } }

struct HOPRoot: View {
    @EnvironmentObject private var store: HOPStore
    @Environment(\.scenePhase) private var phase
    @State private var feature: HOPLink?
    @ObservedObject private var alerts = HOPDeviceAlerts.shared
    var body: some View {
        Group {
            if store.employee == nil { LoginView() }
            else {
                TabView(selection: $store.screen) {
                    NavigationStack { HomeView() }.tabItem { Label("Today", systemImage: "sun.max") }.tag(HOPLink.home)
                    NavigationStack { ScheduleView() }.tabItem { Label("Schedule", systemImage: "calendar") }.tag(HOPLink.schedule)
                    NavigationStack { RequestsView() }.tabItem { Label("Requests", systemImage: "arrow.left.arrow.right") }.tag(HOPLink.requests)
                    NavigationStack { NotificationsView() }.tabItem { Label("Inbox", systemImage: "bell") }.badge(store.unread).tag(HOPLink.notifications)
                    NavigationStack { ProfileView() }.tabItem { Label("Me", systemImage: "person.crop.circle") }.tag(HOPLink.profile)
                }
                .sheet(item: $feature) { route in
                    NavigationStack {
                        Group {
                            switch route {
                            case .availability: AvailabilityView()
                            case .tasks: TasksView()
                            case .parties: PartiesView()
                            case .club: ClubView()
                            default: NotificationsView()
                            }
                        }.toolbar { if route != .availability && route != .club { ToolbarItem(placement: .topBarTrailing) { Button("Done") { feature = nil } } } }
                    }
                }
                .onChange(of: store.screen) { _, route in
                    if [.availability, .tasks, .parties, .club].contains(route) {
                        store.presentedScreen = route; feature = route; store.screen = .profile
                        if route != .availability { Task { await store.ensureLoaded(route) } }
                    } else if feature == nil { Task { await store.ensureLoaded(route) } }
                }
                .onChange(of: feature) { _, value in
                    store.presentedScreen = value
                    if value == nil { Task { await store.ensureLoaded(store.screen) } }
                }
            }
        }
        .task { if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil { await store.restore() } }
        .task(id: phase) {
            guard phase == .active else { return }
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { break }
                tick += 1
                if store.employee != nil && !store.busy && !store.loading { if tick % 3 == 0 { await store.refresh() } else { await store.refreshNotifications() } }
            }
        }
        .onChange(of: phase) { _, value in if value == .active, store.employee != nil, !store.busy { Task { await store.ensureLoaded(store.presentedScreen ?? store.screen) } } }
        .onChange(of: store.employee?.id) { _, value in if value == nil { feature = nil } }
        .task(id: "\(store.employee?.id ?? "")|\(alerts.destination?.id.uuidString ?? "")") {
            if let destination = alerts.destination, store.employee?.id == destination.employeeID {
                await store.selectWeek(destination.date)
                guard store.employee?.id == destination.employeeID else { return }
                store.focusedShiftID = destination.shiftID
                store.screen = .schedule
                alerts.destination = nil
            }
        }
        .overlay(alignment: .top) {
            if let alert = store.inAppAlert, phase == .active {
                HStack(alignment: .top, spacing: 12) {
                    Button { store.inAppAlert = nil; Task { await store.openNotification(alert) } } label: {
                        Label { VStack(alignment: .leading, spacing: 5) { Text(alert.title).font(.headline); Text(alert["message"].text).font(.subheadline).lineLimit(2) } } icon: { Image(systemName: "bell.badge.fill") }
                    }.buttonStyle(.plain)
                    Spacer(minLength: 0)
                    Button { store.inAppAlert = nil } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Dismiss notification")
                }.padding(16).background(HOPStyle.paper, in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(HOPStyle.border)).shadow(color: .black.opacity(0.12), radius: 16, y: 6).padding(12)
            }
        }
        .overlay { if phase != .active && store.employee != nil { ZStack { HOPStyle.background.ignoresSafeArea(); VStack(spacing: 16) { Image("HOPLogo").resizable().scaledToFit().frame(width: 80, height: 80); Text("HOP Staff").font(.title2.bold()); Label("Your information is protected", systemImage: "lock").font(.subheadline).foregroundStyle(.secondary) } } } }
        .alert("House of Pizza", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("OK") { store.message = nil }
        } message: { Text(store.message ?? "") }
    }
}

struct LoginView: View {
    @EnvironmentObject private var store: HOPStore
    @State private var name = ""
    @State private var pin = ""
    @State private var reveal = false
    @FocusState private var focus: Field?
    enum Field { case name, pin }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Image("HOPLogo").resizable().scaledToFit().frame(width: 84, height: 84).accessibilityLabel("House of Pizza")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your shift.\nYour people.").font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text("Welcome to HOP Staff").font(.title3).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Employee name").font(.subheadline.weight(.semibold))
                        TextField("Name used at HOP", text: $name).textContentType(.username).textInputAutocapitalization(.words).autocorrectionDisabled().focused($focus, equals: .name).submitLabel(.next).onSubmit { focus = .pin }.padding(15).background(HOPStyle.background, in: RoundedRectangle(cornerRadius: 14))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Employee PIN").font(.subheadline.weight(.semibold))
                        HStack {
                            Group { if reveal { TextField("4–8 digits", text: $pin) } else { SecureField("4–8 digits", text: $pin) } }.keyboardType(.numberPad).textContentType(.password).focused($focus, equals: .pin)
                            Button { reveal.toggle() } label: { Image(systemName: reveal ? "eye.slash" : "eye").frame(width: 44, height: 44) }.accessibilityLabel(reveal ? "Hide PIN" : "Reveal PIN")
                        }.padding(.leading, 15).background(HOPStyle.background, in: RoundedRectangle(cornerRadius: 14))
                    }
                    if let error = store.loginError { Label(error, systemImage: "exclamationmark.circle").font(.subheadline).foregroundStyle(.red) }
                    Button {
                        focus = nil; HOPStyle.haptic()
                        Task { let submitted = pin; pin = ""; await store.login(name: name, pin: submitted) }
                    } label: { HStack { Spacer(); if store.busy { ProgressView().tint(.white) }; Text(store.busy ? "Signing in…" : "Sign in").fontWeight(.semibold); Spacer() }.padding(.vertical, 10) }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(store.busy || name.trimmingCharacters(in: .whitespaces).isEmpty || pin.count < 4 || pin.count > 8 || pin.contains(where: { !$0.isNumber }))
                    Text("Use your existing HOP name and PIN. Ask your manager if you need access or a PIN reset.").font(.footnote).foregroundStyle(.secondary)
                }.padding(22).background(HOPStyle.surface, in: RoundedRectangle(cornerRadius: 24))
                Text("HOUSE OF PIZZA & PASTA\nGaffney, South Carolina").font(.caption.weight(.medium)).foregroundStyle(.secondary).lineSpacing(5)
            }.padding(28).frame(maxWidth: 520)
        }.background(HOPStyle.background).scrollDismissesKeyboard(.interactively)
    }
}

struct HOPSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View { VStack(alignment: .leading, spacing: 12) { Text(title).font(.title3.weight(.bold)); content }.frame(maxWidth: .infinity, alignment: .leading) }
}
struct HOPCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(alignment: .leading, spacing: 12) { content }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(HOPStyle.surface, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(HOPStyle.border.opacity(0.7), lineWidth: 1)) }
}
struct HOPEmpty: View {
    let title: String
    let detail: String
    var icon = "tray"
    var body: some View { ContentUnavailableView { Label(title, systemImage: icon) } description: { Text(detail) }.padding(.vertical, 8) }
}
struct HOPError: View {
    @EnvironmentObject private var store: HOPStore
    let section: String
    var body: some View {
        if let error = store.errors[section] {
            VStack(alignment: .leading, spacing: 8) { Label(error, systemImage: "wifi.exclamationmark").font(.subheadline); Text("Any content below is from the last successful refresh.").font(.caption).foregroundStyle(.secondary); Button("Try again") { Task { await store.refresh() } }.disabled(store.loading) }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
struct HOPStatus: View {
    let value: String
    var body: some View { Text(value.replacingOccurrences(of: "_", with: " ").capitalized).font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 6).foregroundStyle(value.contains("denied") || value.contains("declined") ? Color.red : HOPStyle.green).background(HOPStyle.green.opacity(0.09), in: Capsule()).fixedSize(horizontal: false, vertical: true) }
}
struct WeekControl: View {
    @EnvironmentObject private var store: HOPStore
    @State private var pickDate = false
    @State private var selectedDate = Date()
    var body: some View {
        HStack {
            Button { Task { await store.changeWeek(-7) } } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Previous week")
            Spacer(minLength: 0)
            Button { selectedDate = HOPCalendar.date(store.week) ?? Date(); pickDate = true } label: { VStack(spacing: 3) { Text("\(HOPCalendar.label(store.week, format: "MMM d")) – \(HOPCalendar.label(HOPCalendar.add(store.week, days: 5), format: "MMM d"))").font(.headline); Text("Choose week · \(String(store.week.prefix(4)))").font(.caption).foregroundStyle(.secondary) }.frame(minHeight: 44) }.buttonStyle(.plain).accessibilityLabel("Choose schedule week")
            Spacer(minLength: 0)
            Button { Task { await store.changeWeek(7) } } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("Next week")
        }.disabled(store.busy).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .sheet(isPresented: $pickDate) {
            NavigationStack {
                VStack {
                    DatePicker("Schedule week", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical).environment(\.timeZone, HOPCalendar.zone).padding()
                    Text("Weeks run Tuesday through Sunday.").font(.footnote).foregroundStyle(.secondary)
                }.navigationTitle("Choose a week").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Show week") {
                                let key = HOPCalendar.tuesday(HOPCalendar.key(selectedDate)); pickDate = false
                                Task { await store.selectWeek(key) }
                            }
                        }
                    }
            }.presentationDetents([.medium, .large])
        }
    }
}
