import SwiftUI

@main struct HOPClubApp:App {var body:some Scene {WindowGroup {ClubRoot()}}}
enum ClubStyle {
    static let green=Color(red:15/255,green:91/255,blue:76/255)
    static let teal=Color(red:11/255,green:122/255,blue:99/255)
    static let red=Color(red:211/255,green:49/255,blue:49/255)
    static let cream=Color(red:245/255,green:242/255,blue:234/255)
}
struct ClubBackground:View {@Environment(\.colorScheme) var scheme;var body:some View {(scheme == .dark ? Color(.systemGroupedBackground) : ClubStyle.cream).ignoresSafeArea()}}
struct ClubPanel<Content:View>:View {@ViewBuilder var content:Content;var body:some View {VStack(alignment:.leading,spacing:14){content}.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(.background,in:RoundedRectangle(cornerRadius:24)).overlay(RoundedRectangle(cornerRadius:24).stroke(.primary.opacity(0.05),lineWidth:1))}}
struct ClubPage<Content:View>:View {@EnvironmentObject var store:ClubStore;@ViewBuilder var content:Content;var body:some View {ScrollView {VStack(alignment:.leading,spacing:20){content}.padding(20).frame(maxWidth:680).frame(maxWidth:.infinity)}.background(ClubBackground()).refreshable {await store.refresh()}}}
struct ClubPill:View {var title:String;var color:Color=ClubStyle.green;var body:some View {Text(title.replacingOccurrences(of:"_",with:" ").capitalized).font(.caption.weight(.semibold)).padding(.horizontal,11).padding(.vertical,6).foregroundStyle(color).background(color.opacity(0.1),in:Capsule())}}
struct ClubPhoto:View {var path:String;var height:CGFloat=150;var body:some View {AsyncImage(url:ClubPolicy.media(path)){phase in if let image=phase.image {image.resizable().scaledToFill()}else{ZStack {ClubStyle.teal.opacity(0.08);Image(systemName:"fork.knife.circle").font(.system(size:42,weight:.light)).foregroundStyle(ClubStyle.green)}}}.frame(maxWidth:.infinity).frame(height:height).clipped().clipShape(RoundedRectangle(cornerRadius:18))}}
struct ClubAction:View {var title:String;var symbol:String;var action:()->Void;var body:some View {Button(action:action){Label(title,systemImage:symbol).font(.headline).frame(maxWidth:.infinity).padding(.vertical,8)}.buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius:16))}}
struct ClubRoot:View {
    @StateObject private var store=ClubStore()
    @AppStorage("hop.club.appearance") private var theme="system"
    @Environment(\.scenePhase) var phase
    var body:some View {
        Group {if store.restoring {ZStack {ClubBackground();ProgressView("Opening HOP Club…")}}else if store.signedIn {tabs}else{ClubLogin()}}
        .environmentObject(store).tint(ClubStyle.green)
        .preferredColorScheme(theme == "dark" ? .dark : theme == "light" ? .light : nil)
        .task {await store.restore()}
        .onChange(of:phase) {_,value in if value == .active && store.signedIn {Task {await store.refresh()}}}
        .overlay {if phase != .active {ZStack {ClubBackground();Text("HOP CLUB").font(.largeTitle.bold()).foregroundStyle(ClubStyle.green)}}}
        .alert("HOP Club",isPresented:Binding(get:{store.error != nil},set:{if !$0{store.error=nil}})){Button("OK"){store.error=nil}}message:{Text(store.error ?? "")}
    }
    private var tabs:some View {TabView(selection:$store.tab) {
        NavigationStack {ClubHome()}.tabItem {Label("Home",systemImage:"house")}.tag("home")
        NavigationStack {ClubMenu()}.tabItem {Label("Menu",systemImage:"fork.knife")}.tag("menu")
        NavigationStack {ClubRewards()}.tabItem {Label("Rewards",systemImage:"gift")}.tag("rewards")
        NavigationStack {ClubMemberCard()}.tabItem {Label("Card",systemImage:"qrcode")}.tag("card")
        NavigationStack {ClubAccount()}.tabItem {Label("Account",systemImage:"person.crop.circle")}.tag("account")
    }.safeAreaInset(edge:.top) {if let notice=store.notice {HStack {Text(notice).font(.caption);Button {store.notice=nil}label:{Image(systemName:"xmark.circle.fill")}}.padding(12).background(.regularMaterial)}}}
}
struct ClubLogin:View {
    @EnvironmentObject var store:ClubStore
    @State private var username=""
    @State private var pin=""
    @State private var reveal=false
    var body:some View {ScrollView {VStack(alignment:.leading,spacing:28) {
        HStack {Image("hop-logo").resizable().scaledToFit().frame(width:58,height:58);Spacer();ClubPill(title:"CUSTOMER APP")}.padding(.top,20)
        VStack(alignment:.leading,spacing:12){Text("Good food.\nGreat rewards.").font(.system(size:43,weight:.bold,design:.rounded));Text("Your little slice of HOP.").font(.title3).foregroundStyle(.secondary)}
        ClubPanel {Label("HOP CLUB",systemImage:"gift.fill").font(.title2.bold()).foregroundStyle(ClubStyle.green);Text("Sign in with your existing member account.").foregroundStyle(.secondary)
            TextField("Phone number or username",text:$username).textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled().padding(14).background(.secondary.opacity(0.08),in:RoundedRectangle(cornerRadius:12))
            HStack {Group {if reveal {TextField("PIN",text:$pin)}else{SecureField("PIN",text:$pin)}}.keyboardType(.numberPad).textContentType(.password);Button {reveal.toggle()}label:{Image(systemName:reveal ? "eye.slash" : "eye")}.accessibilityLabel(reveal ? "Hide PIN" : "Show PIN")}.padding(14).background(.secondary.opacity(0.08),in:RoundedRectangle(cornerRadius:12))
            ClubAction(title:store.busy ? "Signing in…" : "Sign in",symbol:"arrow.right"){Task {await store.login(username:username.trimmingCharacters(in:.whitespaces),pin:pin);pin=""}}.disabled(store.busy || username.isEmpty || pin.count<4)
        }
        Text("Need an account or help with your PIN? Please contact the restaurant. New-account registration is not enabled in this test build.").font(.footnote).foregroundStyle(.secondary)
        Link("Visit House of Pizza",destination:URL(string:ClubPolicy.origin)!).font(.subheadline.bold())
        if store.api.vault.token != nil {Button("Retry saved session"){Task {await store.refresh()}}}
        Text("Native iPhone · 0.1.0 (1)").font(.caption).foregroundStyle(.tertiary)
    }.padding(24).frame(maxWidth:520).frame(maxWidth:.infinity)}.background(ClubBackground())}
}
