import SwiftUI
import AudioToolbox

enum HOPStyle {
    static let green=Color(red:15/255,green:91/255,blue:76/255)
    static let teal=Color(red:11/255,green:122/255,blue:99/255)
    static let red=Color(red:211/255,green:49/255,blue:49/255)
    static let cream=Color(red:245/255,green:242/255,blue:234/255)
    static func band(_ row:J) -> Color { row["role_group"].text == "floor" ? .secondary : row["label"].text.contains("PM") ? green : .blue }
}
struct NativeWorkspaceBackground:View {
    @Environment(\.colorScheme) private var scheme
    var body:some View {(scheme == .dark ? Color(.systemGroupedBackground) : HOPStyle.cream).ignoresSafeArea()}
}
struct HOPPanel<Content:View>:View {
    var title:String?=nil; var subtitle:String?=nil; @ViewBuilder var content:Content
    var body:some View { VStack(alignment:.leading,spacing:16) {
        if let title { VStack(alignment:.leading,spacing:4) { Text(title).font(.title3.bold()); if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) } } }
        content
    }.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(.background,in:RoundedRectangle(cornerRadius:22)).overlay(RoundedRectangle(cornerRadius:22).stroke(.primary.opacity(0.07),lineWidth:1)) }
}
struct StatusTag:View {
    let value:String
    var color:Color { let t=value.lowercased(); if ["failed","denied","off","error","void","cancelled"].contains(where:t.contains) { return HOPStyle.red }; if ["pending","draft","open","unassigned"].contains(where:t.contains) { return .orange }; return HOPStyle.green }
    var body:some View { Text(value.replacingOccurrences(of:"_",with:" ").capitalized).font(.caption.weight(.semibold)).padding(.horizontal,10).padding(.vertical,6).foregroundStyle(color).background(color.opacity(0.10),in:Capsule()) }
}
struct PersonMark:View {
    var name:String
    var body:some View { Text(name.split(separator:" ").prefix(2).compactMap(\.first).map(String.init).joined()).font(.headline).foregroundStyle(HOPStyle.green).frame(width:46,height:46).background(HOPStyle.green.opacity(0.1),in:RoundedRectangle(cornerRadius:15)) }
}
struct NativeEmpty:View { var title:String; var detail:String="Connected records will appear here."; var icon:String="tray"
    var body:some View { ContentUnavailableView(title,systemImage:icon,description:Text(detail)).frame(maxWidth:.infinity,minHeight:200) }
}
struct WeekControl:View {
    @EnvironmentObject var store:NativeStore
    var body:some View { HStack(spacing:12) {
        Button { store.week=HOPDay.add(store.week,-7) } label: { Image(systemName:"chevron.left").frame(width:32,height:32) }.accessibilityLabel("Previous week")
        Text("\(HOPDay.label(store.week,"MMM d")) – \(HOPDay.label(HOPDay.add(store.week,5),"MMM d, yyyy"))").font(.headline).monospacedDigit()
        Button { store.week=HOPDay.add(store.week,7) } label: { Image(systemName:"chevron.right").frame(width:32,height:32) }.accessibilityLabel("Next week")
    }.buttonStyle(.bordered).tint(HOPStyle.green) }
}
struct NativeScreen<Content:View>:View {
    var title:String; var subtitle:String; @ViewBuilder var content:Content
    var body:some View { ScrollView { VStack(alignment:.leading,spacing:22) { VStack(alignment:.leading,spacing:7) { Text(title).font(.largeTitle.bold()); Text(subtitle).font(.body).foregroundStyle(.secondary) }; content }.padding(24).frame(maxWidth:1600,alignment:.topLeading).frame(maxWidth:.infinity) } }
}
struct ErrorNote:View { let text:String; var body:some View { Label(text,systemImage:"exclamationmark.triangle.fill").font(.callout).foregroundStyle(.red).frame(maxWidth:.infinity,alignment:.leading).padding(14).background(Color.red.opacity(0.08),in:RoundedRectangle(cornerRadius:12)) } }
extension J {
    var displayName:String { first("display_name","name","full_name","customer_name","title","invoice_number") }
    var statusText:String { first("status","state") }
}

struct NativeRoot:View {
    @StateObject private var store=NativeStore()
    @State private var selection:NativeModule? = .home
    @AppStorage("hop.ipad.theme") private var savedTheme="system"
    @AppStorage("hop.ipad.sound") private var sound=true
    @State private var incoming:J?
    @Environment(\.scenePhase) private var phase
    var body:some View {
        Group {
            if store.restoring { VStack(spacing:20) { Image(systemName:"fork.knife.circle.fill").font(.system(size:60)).foregroundStyle(HOPStyle.green); ProgressView("Opening HOP…") } }
            else if !store.signedIn { NativeLogin().environmentObject(store) }
            else { workspace.environmentObject(store) }
        }
        .tint(HOPStyle.green)
        .preferredColorScheme(store.theme == "dark" ? .dark : store.theme == "light" ? .light : nil)
        .task { store.theme=savedTheme; await store.restore() }
        .onChange(of:store.notifications) { old,new in
            guard !old.isEmpty else {return};let known=Set(old.map(\.id))
            if let note=new.first(where:{!known.contains($0.id) && $0["read_at"].isNull}) {incoming=note;if sound {AudioServicesPlaySystemSound(1007)}}
        }
        .alert("HOP needs your attention",isPresented:Binding(get:{store.error != nil},set:{ if !$0 {store.error=nil} })) { Button("OK",role:.cancel) { store.error=nil } } message: { Text(store.error ?? "") }
        .overlay { if phase != .active { ZStack { Color(.systemBackground); VStack(spacing:12) { Image(systemName:"lock.shield").font(.largeTitle); Text("HOP Command Center").font(.title2.bold()) } }.ignoresSafeArea() } }
    }
    private var workspace:some View {
        NavigationSplitView {
            List(selection:$selection) {
                Section { VStack(alignment:.leading,spacing:4) { Text("HOP").font(.system(size:38,weight:.bold,design:.serif)); Text("COMMAND CENTER").font(.caption.weight(.semibold)).tracking(2) }.foregroundStyle(HOPStyle.green).padding(.vertical,18) }
                Section("Operations") { ForEach([NativeModule.home,.schedule,.employees,.availability,.tasks,.parties]) { row($0) } }
                Section("Business") { ForEach([NativeModule.inbox,.notifications,.applications,.invoices,.menu,.hopclub,.website,.reports]) { row($0) } }
                Section("System") { row(.settings); row(.watchdog) }
            }.listStyle(.sidebar).navigationTitle("").navigationSplitViewColumnWidth(min:210,ideal:240,max:290)
        } detail: {
            NavigationStack {
                ZStack { NativeWorkspaceBackground(); destination }
                    .navigationTitle(store.module.title).navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItemGroup(placement:.topBarTrailing) {
                            if store.loading { ProgressView() }
                            Button { Task { await store.load() } } label: { Image(systemName:"arrow.clockwise") }.accessibilityLabel("Refresh live data").disabled(store.loading)
                            Menu { Text("\(store.manager.displayName) · Manager"); Text("Native iPad · 0.2.0"); Button("Sign out",role:.destructive) { store.logout() } } label: { Label(store.manager.displayName.isEmpty ? "Manager" : store.manager.displayName,systemImage:"person.crop.circle") }
                        }
                    }
                    .safeAreaInset(edge:.top) { if let failure=store.paths(for:store.module).compactMap({store.failures[$0]}).first { ErrorNote(text:"Some data could not refresh. \(failure)").padding(.horizontal) } }
                    .overlay(alignment:.bottomTrailing) {if let incoming {HOPPanel {HStack {Image(systemName:"bell.badge.fill").foregroundStyle(HOPStyle.red);Text(incoming["title"].text).font(.headline);Spacer();Button {self.incoming=nil}label:{Image(systemName:"xmark")}};Text(incoming.first("message","body")).font(.subheadline).lineLimit(3);Button("Open notifications"){self.incoming=nil;store.module = .notifications}.buttonStyle(.borderedProminent)}.frame(maxWidth:360).padding(20).shadow(color:.black.opacity(0.14),radius:20)}}
                    .safeAreaInset(edge:.bottom) { if let notice=store.notice { HStack { Label(notice,systemImage:"checkmark.circle.fill"); Spacer(); Button {store.notice=nil} label:{Image(systemName:"xmark")} }.font(.subheadline).padding(14).background(.regularMaterial).task(id:notice) { try? await Task.sleep(nanoseconds:5_000_000_000); if store.notice == notice {store.notice=nil} } } }
            }
        }.navigationSplitViewStyle(.balanced)
        .onChange(of:selection) { _,module in if let module {store.module=module;store.selected=nil} }
        .onChange(of:store.module) { _,module in selection=module }
        .task(id:store.module.rawValue+store.week) { await store.load() }
        .task { while !Task.isCancelled { try? await Task.sleep(nanoseconds:30_000_000_000); guard !Task.isCancelled else {break}; if phase == .active && store.signedIn { do {store.data["/api/notifications/manager"]=try await store.api.request("/api/notifications/manager")} catch { if (error as? NativeFailure)?.status == 401 {store.logout()} } } } }
    }
    private func row(_ module:NativeModule) -> some View { NavigationLink(value:module) { HStack { Label(module.title,systemImage:module.icon); Spacer(); if module == .notifications && store.unread>0 { Text("\(store.unread)").font(.caption.bold()).foregroundStyle(.white).padding(5).background(HOPStyle.red,in:Capsule()) } }.padding(.vertical,5) } }
    @ViewBuilder private var destination:some View {
        switch store.module {
        case .home: NativeHome()
        case .schedule: NativeSchedule()
        case .employees: NativeEmployees()
        case .invoices: NativeInvoices()
        case .tasks: NativeTasks()
        case .availability: NativeAvailability()
        case .inbox: NativeInbox()
        case .parties: NativeParties()
        case .menu: NativeMenu()
        case .hopclub: NativeClub()
        case .applications: NativeApplications()
        case .notifications: NativeNotifications()
        case .reports: NativeReports()
        case .website: NativeWebsite()
        case .settings: NativeSettings()
        case .watchdog: NativeWatchdog()
        }
    }
}
private struct NativeLogin:View {
    @EnvironmentObject var store:NativeStore
    @State private var name=""
    @State private var pin=""
    var body:some View { ZStack { HOPStyle.cream.ignoresSafeArea(); VStack(spacing:28) {
        VStack(spacing:8) { Text("HOP").font(.system(size:66,weight:.bold,design:.serif)); Text("Your restaurant. At a glance.").font(.title2) }.foregroundStyle(HOPStyle.green)
        HOPPanel(title:"Welcome to Command Center",subtitle:"Sign in with your existing manager account.") {
            TextField("Manager name",text:$name).textContentType(.username).textInputAutocapitalization(.words).padding(14).background(.quaternary,in:RoundedRectangle(cornerRadius:12))
            SecureField("Manager PIN",text:$pin).textContentType(.password).keyboardType(.numberPad).padding(14).background(.quaternary,in:RoundedRectangle(cornerRadius:12))
            Button { Task { await store.login(name:name.trimmingCharacters(in:.whitespaces),pin:pin); pin="" } } label: { HStack { Spacer(); if store.saving {ProgressView().tint(.white)}; Text("Open workspace").bold(); Image(systemName:"arrow.right"); Spacer() }.padding(10) }.buttonStyle(.borderedProminent).disabled(store.saving || name.isEmpty || pin.isEmpty)
        }.frame(maxWidth:480)
        Label("Connected to the existing HOP system",systemImage:"lock.shield").font(.footnote).foregroundStyle(.secondary)
    }.padding(24) } }
}
