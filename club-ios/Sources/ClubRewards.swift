import SwiftUI

struct ClubRewards:View {
    @EnvironmentObject var store:ClubStore
    @State private var selected:J?
    @State private var request:J?
    var body:some View {ClubPage {
        Text("A little thank-you.\nA lot to enjoy.").font(.largeTitle.bold())
        HStack {ClubPill(title:"\(store.loyalty["points_balance"].int) points");ClubPill(title:"\(store.loyalty["purchase_count"].int) visits")}
        if store.rewards.isEmpty {ContentUnavailableView("No rewards loaded",systemImage:"gift",description:Text("Pull down to refresh the restaurant's reward list."))}
        ForEach(store.rewards){reward in Button {selected=reward}label:{ClubPanel {ClubPhoto(path:reward["image_url"].text,height:155);HStack {Text(reward["title"].text).font(.title3.bold());Spacer();Image(systemName:reward["unlocked"].truth ? "gift.fill" : "lock").foregroundStyle(ClubStyle.green)};Text(reward["description"].text).font(.subheadline).foregroundStyle(.secondary);ProgressView(value:min(reward["progress"].number,max(1,reward["goal"].number)),total:max(1,reward["goal"].number));HStack {Text("\(reward["progress"].int) / \(reward["goal"].int) \(reward["trigger_type"].text == "visit_count" ? "visits" : "points")").font(.caption).foregroundStyle(.secondary);Spacer();ClubPill(title:reward["unlocked"].truth ? "Ready" : "Keep earning")}}}.buttonStyle(.plain)}
        if !store.bundle["redemption_requests"].array.isEmpty {Text("Reward requests").font(.title2.bold());ForEach(store.bundle["redemption_requests"].array){entry in Button {request=entry}label:{ClubPanel {Text(entry["reward_title"].text).font(.headline);ClubPill(title:entry["status"].text);Text(ClubPolicy.date(entry["created_at"].text)).font(.caption).foregroundStyle(.secondary)}}.buttonStyle(.plain)}}
    }.navigationTitle("Rewards").navigationBarTitleDisplayMode(.inline).sheet(item:$selected){ClubRewardDetail(reward:$0)}.sheet(item:$request){ClubRedemption(original:$0)}}
}
struct ClubRewardDetail:View {
    @EnvironmentObject var store:ClubStore
    @Environment(\.dismiss) var dismiss
    var reward:J
    @State private var confirm=false
    @State private var request:J?
    var body:some View {NavigationStack {ClubPage {
        ClubPhoto(path:reward["image_url"].text,height:250)
        Text(reward["title"].text).font(.largeTitle.bold());Text(reward["description"].text).foregroundStyle(.secondary)
        ClubPanel {Text("How it works").font(.headline);Text("Create a request, then show the reward QR to a staff member. HOP validates eligibility and confirms the redemption. Creating a request does not mean your reward has been served.").foregroundStyle(.secondary);Text("Requests expire after \(store.bundle["feature"]["redemption_confirmation_minutes"].int) minutes.").font(.footnote);ClubAction(title:reward["unlocked"].truth ? "Request this reward" : "Not unlocked yet",symbol:"gift"){confirm=true}.disabled(!reward["unlocked"].truth || store.busy || store.pending != nil)}
    }.navigationTitle("Your reward").navigationBarTitleDisplayMode(.inline).toolbar {Button("Done"){dismiss()}}.confirmationDialog("Create a staff-confirmed request for this reward?",isPresented:$confirm,titleVisibility:.visible){Button("Create reward request"){Task {request=await store.redeem(reward)}}}.sheet(item:$request){ClubRedemption(original:$0)}}}
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
