import SwiftUI
import UIKit

struct ClubHome:View {
    @EnvironmentObject var store:ClubStore
    var offers:[J] {store.website["specials"].array.filter {$0["enabled"] != .bool(false)}}
    var body:some View {ClubPage {
        HStack {VStack(alignment:.leading,spacing:6){Text("WELCOME BACK").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.secondary);Text(store.customer["name"].text).font(.largeTitle.bold())};Spacer();Image("hop-logo").resizable().scaledToFit().frame(width:54,height:54)}
        VStack(alignment:.leading,spacing:18) {HStack {Label("YOUR HOP REWARDS",systemImage:"sparkle").font(.caption.bold()).tracking(1);Spacer();Image(systemName:"gift")};Text(store.loyalty["points_balance"].text).font(.system(size:54,weight:.bold,design:.rounded));Text("available points").font(.subheadline);HStack {Text("\(store.loyalty["purchase_count"].int) confirmed visits");Spacer();Button("Show card"){store.tab="card"}.buttonStyle(.bordered).tint(.white)}}.foregroundStyle(.white).padding(24).background(LinearGradient(colors:[ClubStyle.green,ClubStyle.teal],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:28))
        ClubPanel {HStack {Text("One visit closer").font(.title3.bold());Spacer();Image(systemName:"heart.fill").foregroundStyle(ClubStyle.red)};Text(store.loyalty["ten_visit_reward"]["title"].text.isEmpty ? "Your next visit reward" : store.loyalty["ten_visit_reward"]["title"].text).font(.headline);ProgressView(value:Double(store.loyalty["visit_progress"].int),total:Double(max(1,store.loyalty["visit_goal"].int))).tint(ClubStyle.green);Text("\(store.loyalty["visit_progress"].int) / \(max(1,store.loyalty["visit_goal"].int)) visits · credited after staff validation").font(.caption).foregroundStyle(.secondary)}
        ClubAction(title:"Something delicious?",symbol:"fork.knife"){store.tab="menu"}
        if !offers.isEmpty {Text("From the restaurant").font(.title2.bold());ForEach(Array(offers.enumerated()),id:\.offset) {_,offer in ClubPanel {if !offer["image"].text.isEmpty {ClubPhoto(path:offer["image"].text)};ClubPill(title:offer["daysActive"].text.isEmpty ? "Offer" : offer["daysActive"].text);Text(offer["title"].text).font(.title3.bold());Text(offer["description"].text).foregroundStyle(.secondary);Text("Published website offer. Dates and eligibility apply; the checkout quote determines your order price.").font(.caption).foregroundStyle(.secondary)}}}
        if let reward=store.rewards.first(where:{$0["unlocked"].truth}) {Button {store.tab="rewards"}label:{ClubPanel {Label("A reward is ready",systemImage:"gift.fill").font(.headline);Text(reward["title"].text).foregroundStyle(.secondary)}}.buttonStyle(.plain)}
    }.navigationTitle("HOP Club").navigationBarTitleDisplayMode(.inline)}
}
struct ClubQRImage:View {
    var data:Data
    var image:UIImage? {
        guard let qr=ClubQR.parse(data) else{return nil}
        let scale=floor(900/qr.dimension),edge=qr.dimension*scale
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        return UIGraphicsImageRenderer(size:CGSize(width:edge,height:edge),format:format).image {context in
            UIColor.white.setFill();context.fill(CGRect(x:0,y:0,width:edge,height:edge));context.cgContext.setShouldAntialias(false)
            UIColor(red:15/255,green:91/255,blue:76/255,alpha:1).setFill()
            for run in qr.runs {context.fill(CGRect(x:run.x*scale,y:run.y*scale,width:run.width*scale,height:scale))}
        }
    }
    var body:some View {if let image {Image(uiImage:image).interpolation(.none).resizable().scaledToFit().padding(12).background(.white,in:RoundedRectangle(cornerRadius:20)).accessibilityLabel("Secure member QR code for staff to scan")}else {ContentUnavailableView("QR unavailable",systemImage:"qrcode",description:Text("Refresh the card before showing it to staff."))}}
}
struct ClubMemberCard:View {
    @EnvironmentObject var store:ClubStore
    @State private var data:Data?
    @State private var loading=false
    @State private var failure:String?
    var body:some View {ClubPage {
        VStack(alignment:.leading,spacing:22){HStack {Text("HOP CLUB").font(.title2.bold());Spacer();Image(systemName:"sparkle")};Spacer(minLength:12);Text(store.customer["name"].text).font(.title.bold());HStack {Text("MEMBER").font(.caption).tracking(2);Spacer();Text("HOP-"+String(store.customer.id.replacingOccurrences(of:"-",with:"").prefix(8)).uppercased()).font(.caption.monospaced())}}.padding(26).foregroundStyle(.white).background(LinearGradient(colors:[ClubStyle.green,ClubStyle.teal],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:26))
        ClubPanel {Text("Your seat at the table").font(.title2.bold());Text("Show this secure card when staff asks to validate a visit or look up your rewards.").foregroundStyle(.secondary)
            if loading {ProgressView("Getting your secure card…").frame(maxWidth:.infinity,minHeight:240)}else if let data {ClubQRImage(data:data).frame(maxWidth:340).frame(maxWidth:.infinity)}
            if let failure {Text(failure).foregroundStyle(.red)}
            Button("Refresh member QR"){Task {await load()}}.disabled(loading)
            Text("Generated by HOP's server. No phone number or account password is encoded by this app.").font(.caption).foregroundStyle(.secondary)
        }
    }.navigationTitle("Member card").task {await load()}.privacySensitive()}
    private func load() async {loading=true;failure=nil;data=nil;defer {loading=false};do {let value=try await store.api.raw("/api/hopclub/v2/member-qr");guard ClubQR.parse(value) != nil else{throw ClubFailure(status:0,message:"The QR format could not be displayed. Please refresh.")};data=value}catch {failure=error.localizedDescription;if (error as? ClubFailure)?.status == 401 {store.report(error)}}}
}
