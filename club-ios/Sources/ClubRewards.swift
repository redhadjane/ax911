import SwiftUI

struct ClubRewards:View {
    @EnvironmentObject var store:ClubStore
    @State private var selected:J?
    @State private var request:J?
    @State private var filter="all"
    var visibleRewards:[J] {filter == "ready" ? store.rewards.filter {$0["unlocked"].truth} : store.rewards}
    var body:some View {ClubPage {
        ClubHeading(eyebrow:"THE GOOD PART",title:"Little perks.\nBig thank-you.",subtitle:"Good things come back around.")
        HStack(spacing:20){VStack(alignment:.leading,spacing:6){Text(store.loyalty["points_balance"].text).font(.system(.largeTitle,design:.rounded,weight:.bold));Text("AVAILABLE POINTS").font(.caption2.bold()).tracking(1.5)};Spacer();VStack(alignment:.trailing,spacing:6){Image(systemName:"gift.fill").font(.title);Text("\(store.rewards.filter {$0["unlocked"].truth}.count) ready to enjoy").font(.caption.bold())}}.foregroundStyle(.white).padding(24).background(ClubStyle.green,in:RoundedRectangle(cornerRadius:26))
        Picker("Rewards",selection:$filter){Text("All rewards").tag("all");Text("Ready for you").tag("ready")}.pickerStyle(.segmented)
        if store.rewards.isEmpty {ContentUnavailableView("No rewards loaded",systemImage:"gift",description:Text("Pull down to refresh the restaurant's reward list."))}
        else if visibleRewards.isEmpty {ContentUnavailableView("Good things are on the way",systemImage:"sparkles",description:Text("Your progress is saved. Explore all rewards to see what's next."))}
        ForEach(visibleRewards){reward in Button {ClubStyle.touch();selected=reward}label:{ClubRewardTile(reward:reward)}.buttonStyle(ClubPressStyle())}
        if !store.bundle["redemption_requests"].array.isEmpty {ClubSectionTitle(title:"Your reward requests");ForEach(store.bundle["redemption_requests"].array){entry in Button {request=entry}label:{ClubPanel {ClubLinkRow(symbol:"ticket",title:entry["reward_title"].text,subtitle:ClubPolicy.date(entry["created_at"].text));ClubPill(title:entry["status"].text)}}.buttonStyle(ClubPressStyle())}}
    }.navigationTitle("Rewards").navigationBarTitleDisplayMode(.inline).sheet(item:$selected){ClubRewardDetail(reward:$0).presentationDragIndicator(.visible).presentationCornerRadius(32)}.sheet(item:$request){ClubRedemption(original:$0).presentationDragIndicator(.visible)}}
}
struct ClubRewardTile:View {
    @Environment(\.dynamicTypeSize) var textSize
    var reward:J
    var body:some View {ClubPanel {ViewThatFits(in:.horizontal){HStack(alignment:.top,spacing:16){ClubPhoto(path:reward["image_url"].text,height:100).frame(width:100);details};VStack(alignment:.leading,spacing:14){ClubPhoto(path:reward["image_url"].text,height:165);details}};ProgressView(value:max(0,min(reward["progress"].number,max(1,reward["goal"].number))),total:max(1,reward["goal"].number)).tint(ClubStyle.accent);HStack {Text("\(reward["progress"].int) / \(reward["goal"].int) \(reward["trigger_type"].text == "visit_count" ? "visits" : "points")").font(.caption).foregroundStyle(.secondary);Spacer();Image(systemName:"arrow.up.right").font(.caption.bold()).foregroundStyle(ClubStyle.accent)}}}
    private var details:some View {VStack(alignment:.leading,spacing:10){ClubPill(title:reward["unlocked"].truth ? "Ready for you" : "Keep earning");Text(reward["title"].text).font(.headline).foregroundStyle(.primary).fixedSize(horizontal:false,vertical:true)}.frame(maxWidth:.infinity,alignment:.leading)}
}
struct ClubRewardDetail:View {
    @EnvironmentObject var store:ClubStore
    @Environment(\.dismiss) var dismiss
    var reward:J
    @State private var confirm=false
    @State private var request:J?
    var body:some View {NavigationStack {ClubPage {
        ClubPhoto(path:reward["image_url"].text,height:260)
        ClubPill(title:reward["unlocked"].truth ? "Yours to request" : "A little closer every visit")
        ClubHeading(eyebrow:"A THANK-YOU FROM HOP",title:reward["title"].text,subtitle:reward["description"].text)
        ClubPanel {Text("From your phone to your table.").font(.title3.bold());step("1",title:"Request your reward",detail:"HOP checks your live eligibility.");step("2",title:"Show the reward QR",detail:"A staff member confirms it in the restaurant.");step("3",title:"Enjoy a little extra",detail:"Your balance updates after confirmation.");if store.bundle["feature"]["redemption_confirmation_minutes"].int>0 {Text("Confirmation window: \(store.bundle["feature"]["redemption_confirmation_minutes"].int) minutes.").font(.caption).foregroundStyle(.secondary)}}
    }.navigationTitle("Your reward").navigationBarTitleDisplayMode(.inline).toolbar {ClubSheetClose()}.safeAreaInset(edge:.bottom,spacing:0){ClubAction(title:store.busy ? "Requesting…" : reward["unlocked"].truth ? "Request this reward" : "Not unlocked yet",symbol:"gift"){confirm=true}.disabled(!reward["unlocked"].truth || store.busy || store.pending != nil).padding(18).background(.regularMaterial)}.confirmationDialog("Create a staff-confirmed request for this reward?",isPresented:$confirm,titleVisibility:.visible){Button("Create reward request"){Task {request=await store.redeem(reward)}}}.sheet(item:$request){ClubRedemption(original:$0)}}}
    private func step(_ number:String,title:String,detail:String)->some View {HStack(alignment:.top,spacing:14){Text(number).font(.caption.bold()).foregroundStyle(ClubStyle.accent).frame(width:30,height:30).background(ClubStyle.accent.opacity(0.09),in:Circle());VStack(alignment:.leading,spacing:4){Text(title).font(.subheadline.bold());Text(detail).font(.caption).foregroundStyle(.secondary)}}}
}
struct ClubRedemption:View {
    @EnvironmentObject var store:ClubStore
    @Environment(\.dismiss) var dismiss
    var original:J
    @State private var request:J = .null
    @State private var qr:Data?
    @State private var failure:String?
    var body:some View {NavigationStack {ClubPage {
        Text((request.isNull ? original : request)["reward_title"].text).font(.largeTitle.bold())
        ClubPill(title:request["status"].text)
        Text("Show this request to staff. Only the restaurant can confirm your redemption.").foregroundStyle(.secondary)
        TimelineView(.periodic(from:.now,by:1)){context in
            let expiry=ISO8601DateFormatter.clubDate(request["expires_at"].text)
            let active=request["status"].text == "pending_staff_confirmation" && (expiry ?? .distantPast)>context.date
            if active,let qr {ClubQRImage(data:qr);Text("Valid until \(ClubPolicy.date(request["expires_at"].text))").font(.caption).foregroundStyle(.secondary)}else{ClubPanel {Image(systemName:active ? "hourglass" : "checkmark.shield").font(.largeTitle).foregroundStyle(ClubStyle.green);Text(active ? "Loading secure QR…" : "This request no longer has an active confirmation QR.")}}
        }
        if let failure {Text(failure).foregroundStyle(.red)}
        Button("Refresh status"){Task {await load()}}
        if !request["short_id"].text.isEmpty {Text("Request #"+request["short_id"].text).font(.caption.monospaced())}
    }.navigationTitle("Reward request").navigationBarTitleDisplayMode(.inline).toolbar {Button("Done"){dismiss()}}.task {while !Task.isCancelled {await load();try? await Task.sleep(nanoseconds:20_000_000_000)}}.privacySensitive()}}
    private func load() async {do {let result=try await store.api.get("/api/hopclub/v2/redemptions/\(original.id)");request=result["redemption"];failure=nil;if request["status"].text == "pending_staff_confirmation" {qr=try await store.api.raw("/api/hopclub/v2/redemptions/\(original.id)/qr")}else{qr=nil}}catch {failure=error.localizedDescription;qr=nil;if (error as? ClubFailure)?.status == 401 {store.report(error)}}}
}
extension ISO8601DateFormatter {
    static func clubDate(_ value:String)->Date? {let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds];return f.date(from:value) ?? ISO8601DateFormatter().date(from:value)}
}
