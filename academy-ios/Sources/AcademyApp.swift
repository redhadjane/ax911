import SwiftUI

@main
struct HOPAcademyApp: App {
    @StateObject private var store = AcademyStore()
    @AppStorage("academy.appearance") private var appearance = "system"
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            AcademyRoot().environmentObject(store)
                .tint(AcademyPalette.jade)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
                .onChange(of:scenePhase) { _, phase in if phase == .active { store.tick(); store.suspendClock() } else { store.suspendClock() } }
        }
    }
}
enum AcademyDestination: String, CaseIterable, Identifiable {
    case today, practice, words, progress, resources
    var id: String { rawValue }
    var title: String { switch self { case .today: "Today"; case .practice: "Practice"; case .words: "Words"; case .progress: "Progress"; case .resources: "Sources" } }
    var icon: String { switch self { case .today: "square.grid.2x2"; case .practice: "bolt.circle"; case .words: "text.book.closed"; case .progress: "chart.xyaxis.line"; case .resources: "books.vertical" } }
}
struct AcademyRoot: View {
    @EnvironmentObject var store: AcademyStore
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var destination: AcademyDestination = .today
    @State private var settings = false
    private var sessionBinding: Binding<Bool> { Binding(get:{ store.presentedSession != nil },set:{ if !$0 { store.presentedSession = nil } }) }
    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    List {
                        Section { VStack(alignment:.leading,spacing:8) { Image(systemName:"leaf.fill").font(.largeTitle).foregroundStyle(AcademyPalette.jade); Text("HOP Academy").font(.title2.bold()); Text("Your experience.\nA new qualification.").font(.subheadline).foregroundStyle(.secondary) }.padding(.vertical,20) }
                        ForEach(AcademyDestination.allCases) { item in
                            Button { destination = item } label: { Label(item.title,systemImage:item.icon).font(.headline).padding(.vertical,7).foregroundStyle(destination == item ? AcademyPalette.jade : Color.primary) }
                                .listRowBackground(destination == item ? AcademyPalette.jade.opacity(0.12) : Color.clear)
                        }
                        Section { Label("Works offline",systemImage:"checkmark.icloud").foregroundStyle(.secondary).font(.caption) }
                    }.listStyle(.sidebar).navigationSplitViewColumnWidth(min:240,ideal:260,max:300)
                } detail: { NavigationStack { page(destination).toolbar { settingsButton } } }
            } else {
                TabView(selection:$destination) {
                    ForEach(AcademyDestination.allCases) { item in
                        NavigationStack { page(item).toolbar { settingsButton } }.tabItem { Label(item.title,systemImage:item.icon) }.tag(item)
                    }
                }
            }
        }
        .sheet(isPresented:$settings) { AcademySettings().environmentObject(store) }
        .fullScreenCover(isPresented:sessionBinding) { if let id = store.presentedSession { StudyWorkspace(sessionID:id).environmentObject(store) } }
        .alert("Academy",isPresented:Binding(get:{store.message != nil && store.presentedSession == nil && !settings},set:{if !$0 {store.message=nil}})) { Button("OK",role:.cancel) { store.message=nil } } message: { Text(store.message ?? "") }
    }
    @ToolbarContentBuilder private var settingsButton: some ToolbarContent {
        ToolbarItem(placement:.topBarTrailing) { Button { settings=true } label: { Image(systemName:"slider.horizontal.3").font(.subheadline.weight(.semibold)).padding(7) }.accessibilityLabel("Study settings") }
    }
    @ViewBuilder private func page(_ item: AcademyDestination) -> some View {
        switch item {
        case .today: TodayView()
        case .practice: PracticeView()
        case .words: VocabularyView()
        case .progress: ProgressDashboard()
        case .resources: SourcesView()
        }
    }
}
