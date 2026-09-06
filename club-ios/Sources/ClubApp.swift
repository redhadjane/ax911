import SwiftUI

@main struct HOPClubApp:App {var body:some Scene {WindowGroup {ClubRoot()}}}
struct ClubRoot:View {
    @StateObject private var store=ClubStore()
    @AppStorage("hop.club.appearance") private var theme="system"
    @Environment(\.scenePhase) var phase
    var body:some View {
        Group {if store.restoring {ZStack {ClubBackground();VStack(spacing:24){Image("hop-logo").resizable().scaledToFit().frame(width:80,height:80);Text("Your little slice of HOP.").font(.title2.bold());ProgressView()}}}else if store.signedIn {tabs}else{ClubLogin()}}
        .environmentObject(store).tint(ClubStyle.accent)
        .preferredColorScheme(theme == "dark" ? .dark : theme == "light" ? .light : nil)
        .task {await store.restore()}
        .onChange(of:phase) {_,value in if value == .active && store.signedIn {Task {await store.refresh()}}}
        .overlay {if phase != .active {ZStack {ClubBackground();Text("HOP CLUB").font(.largeTitle.bold()).foregroundStyle(ClubStyle.accent)}}}
        .alert("HOP Club",isPresented:Binding(get:{store.error != nil},set:{if !$0{store.error=nil}})){Button("OK"){store.error=nil}}message:{Text(store.error ?? "")}
    }
    private var tabs:some View {TabView(selection:$store.tab) {
        NavigationStack {ClubHome()}.tabItem {Label("Discover",systemImage:"sparkles")}.tag("home")
        NavigationStack {ClubMenu()}.tabItem {Label("Menu",systemImage:"fork.knife")}.tag("menu")
        NavigationStack {ClubMemberCard()}.tabItem {Label("Club card",systemImage:"qrcode")}.tag("card")
        NavigationStack {ClubRewards()}.tabItem {Label("Rewards",systemImage:"gift")}.tag("rewards")
        NavigationStack {ClubAccount()}.tabItem {Label("You",systemImage:"person.crop.circle")}.tag("account")
    }.onChange(of:store.tab){_,_ in ClubStyle.touch()}
    .safeAreaInset(edge:.top,spacing:0) {if let notice=store.notice {HStack(alignment:.top,spacing:12){Image(systemName:"info.circle.fill").foregroundStyle(ClubStyle.accent);Text(notice).font(.subheadline);Spacer(minLength:0);Button {store.notice=nil}label:{Image(systemName:"xmark.circle.fill").frame(minWidth:32,minHeight:32)}.accessibilityLabel("Dismiss message")}.padding(16).background(.regularMaterial)}}}
}
struct ClubLogin:View {
    @EnvironmentObject var store:ClubStore
    @State private var username=""
    @State private var pin=""
    @State private var reveal=false
    @FocusState private var field:Field?
    private enum Field {case username,pin}
    var body:some View {ScrollView {VStack(alignment:.leading,spacing:28) {
        HStack {Image("hop-logo").resizable().scaledToFit().frame(width:58,height:58);Spacer();Text("GAFFNEY, SC").font(.caption2.bold()).tracking(2).foregroundStyle(.secondary)}.padding(.top,20)
        hero
        ClubPanel {
            VStack(alignment:.leading,spacing:6){Text("Welcome to the club.").font(.title2.bold());Text("Sign in to your existing member account.").font(.subheadline).foregroundStyle(.secondary)}
            VStack(alignment:.leading,spacing:8){Text("PHONE OR USERNAME").font(.caption2.bold()).tracking(1).foregroundStyle(.secondary);TextField("Your member login",text:$username).textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled().focused($field,equals:.username).submitLabel(.next).onSubmit {field = .pin}.padding(16).background(.secondary.opacity(0.07),in:RoundedRectangle(cornerRadius:16))}
            VStack(alignment:.leading,spacing:8){Text("MEMBER PIN").font(.caption2.bold()).tracking(1).foregroundStyle(.secondary);HStack {Group {if reveal {TextField("Enter PIN",text:$pin)}else{SecureField("Enter PIN",text:$pin)}}.keyboardType(.numberPad).textContentType(.password).focused($field,equals:.pin);Button {reveal.toggle()}label:{Image(systemName:reveal ? "eye.slash" : "eye").frame(width:44,height:44)}.accessibilityLabel(reveal ? "Hide PIN" : "Show PIN")}.padding(.leading,16).padding(.trailing,6).padding(.vertical,4).background(.secondary.opacity(0.07),in:RoundedRectangle(cornerRadius:16))}
            ClubAction(title:store.busy ? "Signing in…" : "Let's get you in",symbol:store.busy ? "hourglass" : "arrow.right"){field=nil;Task {await store.login(username:username.trimmingCharacters(in:.whitespaces),pin:pin);pin=""}}.disabled(store.busy || username.isEmpty || pin.count<4)
        }
        VStack(alignment:.leading,spacing:12){Text("Need a membership or PIN help?").font(.subheadline.bold());Text("Contact the restaurant. Registration and account recovery aren't available in this test build.").font(.footnote).foregroundStyle(.secondary);Link("Visit House of Pizza ↗",destination:URL(string:ClubPolicy.origin)!).font(.subheadline.bold())}
        if store.api.vault.token != nil {Button("Retry saved session"){Task {await store.refresh()}}}
        Text("HOP CLUB • iOS EDITION 0.2.0").font(.caption2.bold()).tracking(2).foregroundStyle(.tertiary)
    }.padding(24).frame(maxWidth:520).frame(maxWidth:.infinity)}.background(ClubBackground()).scrollDismissesKeyboard(.interactively).toolbar {ToolbarItemGroup(placement:.keyboard){Spacer();Button("Done"){field=nil}}}}
    private var hero:some View {VStack(alignment:.leading,spacing:18){Text("GOOD FOOD.\nGOOD COMPANY.").font(.caption2.bold()).tracking(3).foregroundStyle(ClubStyle.gold);Text("A little more\nto love.").font(.system(.largeTitle,design:.serif,weight:.bold)).foregroundStyle(.white);Text("Your favorites. Your rewards.\nAlways a place for you at HOP.").font(.subheadline).foregroundStyle(.white.opacity(0.8));HStack(spacing:8){Image(systemName:"sparkle");Text("HOUSE OF PIZZA & PASTA").tracking(1.5)}.font(.caption2.bold()).foregroundStyle(.white.opacity(0.75))}.padding(28).frame(maxWidth:.infinity,alignment:.leading).background {RoundedRectangle(cornerRadius:32).fill(LinearGradient(colors:[ClubStyle.green,Color(red:0.025,green:0.19,blue:0.16)],startPoint:.topLeading,endPoint:.bottomTrailing)).overlay(alignment:.trailing){Circle().stroke(.white.opacity(0.06),lineWidth:45).frame(width:230,height:230).offset(x:125,y:5)}.clipped()}.clipShape(RoundedRectangle(cornerRadius:32))}
}
