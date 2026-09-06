import SwiftUI
import UIKit

struct ClubHome:View {
    @EnvironmentObject var store:ClubStore
    var offers:[J] {store.website["specials"].array.filter {$0["enabled"] != .bool(false)}}
    @State private var offer:J?
    var body:some View {ClubPage {
        HStack(alignment:.top){ClubHeading(eyebrow:"YOUR NEIGHBORHOOD FAVORITE",title:"Hey, \(store.customer["name"].text.components(separatedBy:" ").first ?? "friend").",subtitle:"Good to have you back.");Spacer();Image("hop-logo").resizable().scaledToFit().frame(width:50,height:50)}
        membership
        HStack(spacing:12){Button {store.tab="menu"}label:{ClubQuickTile(symbol:"fork.knife",title:"Find your favorite",subtitle:"Explore the menu")};Button {store.tab="card"}label:{ClubQuickTile(symbol:"qrcode.viewfinder",title:"Show your card",subtitle:"Scan with staff")}}.buttonStyle(ClubPressStyle())
        if let order=store.orders.first {NavigationLink {ClubOrderDetail(orderID:order.id)}label:{ClubPanel {ClubLinkRow(symbol:"bag",title:"Your latest order",subtitle:ClubPolicy.date(order["created_at"].text));HStack {ClubPill(title:order["status"].text);Spacer();Text(ClubPolicy.money(order["total"].number)).font(.headline)}}}.buttonStyle(.plain)}
        visits
        if let reward=store.rewards.first(where:{$0["unlocked"].truth}) {Button {store.tab="rewards"}label:{ClubPanel {ClubLinkRow(symbol:"gift.fill",title:"Something good is waiting",subtitle:reward["title"].text)}}.buttonStyle(ClubPressStyle())}
        if !offers.isEmpty {ClubSectionTitle(title:"Fresh from HOP",detail:"Restaurant offers");ScrollView(.horizontal){LazyHStack(alignment:.top,spacing:14){ForEach(Array(offers.enumerated()),id:\.offset){_,entry in Button {offer=entry}label:{ClubPanel {ClubPhoto(path:entry["image"].text,height:145);Text(entry["title"].text).font(.title3.bold()).foregroundStyle(.primary).lineLimit(2);Text(entry["description"].text).font(.subheadline).foregroundStyle(.secondary).lineLimit(2);Label("See the details",systemImage:"arrow.up.right").font(.caption.bold()).foregroundStyle(ClubStyle.accent)}.frame(width:275)}}.buttonStyle(ClubPressStyle())}.padding(.bottom,8)}.scrollIndicators(.hidden)}
        HStack {Spacer();Image(systemName:"heart.fill").foregroundStyle(ClubStyle.red);Text("Good pizza. Brighter together.").foregroundStyle(.secondary);Spacer()}.font(.caption)
    }.toolbar(.hidden,for:.navigationBar).sheet(item:$offer){entry in NavigationStack {ClubPage {ClubPhoto(path:entry["image"].text,height:240);ClubHeading(eyebrow:"FROM THE RESTAURANT",title:entry["title"].text,subtitle:entry["description"].text);if !entry["daysActive"].text.isEmpty {ClubPill(title:entry["daysActive"].text)};Text("Published restaurant offer. Dates and eligibility apply; your server quote determines checkout pricing.").font(.footnote).foregroundStyle(.secondary);ClubAction(title:"Explore the menu",symbol:"arrow.right"){offer=nil;store.tab="menu"}}.toolbar {ClubSheetClose()}}.presentationDragIndicator(.visible)}}
    private var membership:some View {VStack(alignment:.leading,spacing:24){HStack {Text("HOP / CLUB").font(.system(.headline,design:.serif)).tracking(2);Spacer();Text("MEMBER").font(.caption2.bold()).tracking(2).foregroundStyle(ClubStyle.gold)};HStack(alignment:.bottom){VStack(alignment:.leading,spacing:3){Text(store.loyalty["points_balance"].text).font(.system(size:52,weight:.semibold,design:.rounded)).minimumScaleFactor(0.65).lineLimit(1);Text("POINTS TO ENJOY").font(.caption2.bold()).tracking(2).foregroundStyle(.white.opacity(0.65))};Spacer();Image(systemName:"sparkles").font(.system(size:40,weight:.ultraLight)).foregroundStyle(ClubStyle.gold)};Rectangle().fill(.white.opacity(0.16)).frame(height:1);HStack {Text("\(store.loyalty["purchase_count"].int) validated visits").font(.subheadline);Spacer();Button {store.tab="rewards"}label:{HStack {Text("Your rewards");Image(systemName:"arrow.up.right")}.font(.caption.bold()).padding(12).background(.white.opacity(0.13),in:Capsule())}}}.foregroundStyle(.white).padding(26).background(LinearGradient(colors:[ClubStyle.green,Color(red:0.03,green:0.19,blue:0.16)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:30)).shadow(color:ClubStyle.green.opacity(0.15),radius:18,x:0,y:10)}
    private var visits:some View {ClubPanel {HStack(alignment:.top){VStack(alignment:.leading,spacing:5){Text("A little closer to delicious.").font(.title3.bold());Text(store.loyalty["ten_visit_reward"]["title"].text.isEmpty ? "Your next visit reward" : store.loyalty["ten_visit_reward"]["title"].text).font(.subheadline).foregroundStyle(.secondary)};Spacer();ClubIcon(symbol:"heart.fill",color:ClubStyle.red)};ClubVisitTrack(progress:store.loyalty["visit_progress"].int,goal:store.loyalty["visit_goal"].int);HStack {Text("\(store.loyalty["visit_progress"].int) / \(max(1,store.loyalty["visit_goal"].int)) visits").font(.subheadline.bold());Spacer();Text("Validated by HOP").font(.caption).foregroundStyle(.secondary)}}}
}
struct ClubQuickTile:View {var symbol:String;var title:String;var subtitle:String;var body:some View {VStack(alignment:.leading,spacing:12){ClubIcon(symbol:symbol);Text(title).font(.subheadline.bold()).foregroundStyle(.primary);Text(subtitle).font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,minHeight:135,alignment:.topLeading).padding(16).background(ClubStyle.surface,in:RoundedRectangle(cornerRadius:24))}}
struct ClubQRImage:View {
    var data:Data
    @State private var rendered:UIImage?
    @State private var renderedData:Data?
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
    var body:some View {Group {if renderedData != data {ProgressView("Preparing secure QR…").frame(minHeight:240)}else if let rendered {Image(uiImage:rendered).interpolation(.none).resizable().scaledToFit().padding(12).background(.white,in:RoundedRectangle(cornerRadius:20)).accessibilityLabel("Secure member QR code for staff to scan")}else {ContentUnavailableView("QR unavailable",systemImage:"qrcode",description:Text("Refresh the card before showing it to staff."))}}.task(id:data){rendered=image;renderedData=data}}
}
struct ClubMemberCard:View {
    @EnvironmentObject var store:ClubStore
    @State private var data:Data?
    @State private var loading=false
    @State private var failure:String?
    var body:some View {ClubPage {
        ClubHeading(eyebrow:"MEMBERSHIP",title:"Your seat at the table.",subtitle:"One card. All your HOP goodness.")
        VStack(spacing:0){VStack(alignment:.leading,spacing:24){HStack {Text("HOP / CLUB").font(.system(.title2,design:.serif,weight:.bold)).tracking(2);Spacer();Image(systemName:"sparkle").foregroundStyle(ClubStyle.gold)};Text(store.customer["name"].text).font(.title2.bold());HStack {Text("MEMBER").font(.caption2.bold()).tracking(2);Spacer();Text("HOP-"+String(store.customer.id.replacingOccurrences(of:"-",with:"").prefix(8)).uppercased()).font(.caption.monospaced())}}.padding(26).foregroundStyle(.white).background(LinearGradient(colors:[ClubStyle.green,Color(red:0.03,green:0.19,blue:0.16)],startPoint:.topLeading,endPoint:.bottomTrailing))
        VStack(spacing:18){Text("SCAN WITH HOP STAFF").font(.caption2.bold()).tracking(2).foregroundStyle(ClubStyle.green)
            if loading {ProgressView("Getting your secure card…").frame(maxWidth:.infinity,minHeight:240)}else if let data {ClubQRImage(data:data).frame(maxWidth:340).frame(maxWidth:.infinity)}
            if let failure {Text(failure).foregroundStyle(.red)}
            Button {Task {await load()}}label:{Label("Refresh secure code",systemImage:"arrow.clockwise").font(.subheadline.bold()).padding(12)}.disabled(loading).tint(ClubStyle.green)
        }.padding(20).frame(maxWidth:.infinity).background(.white).environment(\.colorScheme,.light)}.clipShape(RoundedRectangle(cornerRadius:30)).overlay(RoundedRectangle(cornerRadius:30).stroke(.primary.opacity(0.06))).shadow(color:.black.opacity(0.06),radius:18,x:0,y:8)
        ClubPanel {HStack {ClubIcon(symbol:"checkmark.shield");VStack(alignment:.leading,spacing:5){Text("Made to be shown. Kept secure.").font(.subheadline.bold());Text("Staff validates your visits and rewards. This server-issued code doesn't display your phone number or PIN.").font(.caption).foregroundStyle(.secondary)}}}
    }.navigationTitle("Club card").navigationBarTitleDisplayMode(.inline).task {await load()}.privacySensitive()}
    private func load() async {loading=true;failure=nil;data=nil;defer {loading=false};do {let value=try await store.api.raw("/api/hopclub/v2/member-qr");guard ClubQR.parse(value) != nil else{throw ClubFailure(status:0,message:"The QR format could not be displayed. Please refresh.")};data=value}catch {failure=error.localizedDescription;if (error as? ClubFailure)?.status == 401 {store.report(error)}}}
}
