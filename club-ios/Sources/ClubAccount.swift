import SwiftUI

struct ClubAccount:View {
    @EnvironmentObject var store:ClubStore
    @AppStorage("hop.club.appearance") private var theme="system"
    @State private var logout=false
    @State private var clear=false
    @State private var settings=false
    var body:some View {ClubPage {
        ClubHeading(eyebrow:"YOUR CORNER OF HOP",title:"Make yourself at home.")
        ClubPanel {HStack(spacing:16){Text(String(store.customer["name"].text.prefix(1)).uppercased()).font(.system(.title,design:.serif,weight:.bold)).foregroundStyle(ClubStyle.accent).frame(width:62,height:62).background(ClubStyle.accent.opacity(0.1),in:RoundedRectangle(cornerRadius:22));VStack(alignment:.leading,spacing:6){Text(store.customer["name"].text).font(.title2.bold());Text(store.customer["phone"].text).font(.subheadline).foregroundStyle(.secondary)}};Divider();HStack {Label("HOP Club member",systemImage:"checkmark.seal.fill").font(.caption.bold()).foregroundStyle(ClubStyle.accent);Spacer();if let sync=store.lastSync {Text("Updated \(sync.formatted(date:.omitted,time:.shortened))").font(.caption2).foregroundStyle(.secondary)}}}
        if let pending=store.pending {ClubPanel {Label("A request needs your review",systemImage:"exclamationmark.triangle").font(.headline).foregroundStyle(.orange);Text("A response may have been interrupted. Check order and reward history first. Retry keeps the original request key to prevent duplicates.");if pending["kind"].text == "order" {NavigationLink("Review pickup request"){ClubCart()}}else{Button("Retry same reward request"){Task {_ = await store.redeem(.object(["id":pending["body"]["reward_rule_id"]]))}}};Button("I reviewed history — clear pending request",role:.destructive){clear=true}.disabled(store.busy)}}
        ClubSectionTitle(title:"Your HOP life")
        ClubPanel {NavigationLink {ClubOrders()}label:{ClubLinkRow(symbol:"bag",title:"Orders & pickup",subtitle:"Follow your latest request")};Divider();NavigationLink {ClubActivity()}label:{ClubLinkRow(symbol:"sparkles",title:"Points activity",subtitle:"Every little thank-you")};Divider();Button {store.tab="rewards"}label:{ClubLinkRow(symbol:"gift",title:"Rewards & requests",subtitle:"Your next little extra")};Divider();Button {store.tab="card"}label:{ClubLinkRow(symbol:"qrcode",title:"Membership card",subtitle:"Ready when you arrive")}}.buttonStyle(.plain)
        ClubSectionTitle(title:"Just the way you like it")
        ClubPanel {Button {settings=true}label:{ClubLinkRow(symbol:"slider.horizontal.3",title:"App preferences",subtitle:"Appearance, touch & accessibility")};Divider();Link(destination:URL(string:ClubPolicy.origin)!){ClubLinkRow(symbol:"arrow.up.right.square",title:"Visit House of Pizza",subtitle:"Restaurant information & contact")}}.buttonStyle(.plain)
        ClubPanel {HStack(alignment:.top,spacing:14){ClubIcon(symbol:"bell.badge");VStack(alignment:.leading,spacing:7){Text("Stay in the know").font(.headline);Text("Offers and order status update when you open HOP Club. Pull down to refresh anytime.").font(.subheadline).foregroundStyle(.secondary);Text("This SideStore test build does not support background push.").font(.caption).foregroundStyle(.secondary)}}}
        Button(role:.destructive){logout=true}label:{Label("Sign out of this iPhone",systemImage:"rectangle.portrait.and.arrow.right").font(.subheadline.bold()).frame(maxWidth:.infinity,minHeight:48)}.disabled(store.busy)
        Text("HOP CLUB • iOS EDITION 0.2.0 (2)").font(.caption2.bold()).tracking(2).foregroundStyle(.tertiary).frame(maxWidth:.infinity)
    }.navigationTitle("You").navigationBarTitleDisplayMode(.inline).sheet(isPresented:$settings){ClubPreferences().presentationDragIndicator(.visible).presentationCornerRadius(32)}.confirmationDialog("Sign out of this iPhone? Your account stays with HOP.",isPresented:$logout,titleVisibility:.visible){Button("Sign out",role:.destructive){store.logout()}}.confirmationDialog("Only clear this after checking history. Clearing does not cancel an order or reward already received by HOP.",isPresented:$clear,titleVisibility:.visible){Button("Clear pending request",role:.destructive){store.clearPendingAfterReview()}}}
}
struct ClubPreferences:View {
    @AppStorage("hop.club.appearance") private var theme="system"
    @AppStorage("hop.club.haptics") private var haptics=true
    @Environment(\.accessibilityReduceMotion) var reduced
    var body:some View {NavigationStack {ClubPage {
        ClubHeading(eyebrow:"FEELS LIKE YOU",title:"The little details.",subtitle:"Make HOP Club feel at home on your iPhone.")
        ClubPanel {Text("Choose your atmosphere").font(.title3.bold());HStack(spacing:10){appearance("System",id:"system",symbol:"circle.lefthalf.filled");appearance("Light",id:"light",symbol:"sun.max");appearance("Dark",id:"dark",symbol:"moon.stars")}}
        ClubPanel {Toggle(isOn:$haptics){VStack(alignment:.leading,spacing:5){Text("Gentle haptics").font(.headline);Text("A little feedback when you choose.").font(.caption).foregroundStyle(.secondary)}};Divider();HStack {Text("Motion").font(.headline);Spacer();ClubPill(title:reduced ? "Reduced" : "Standard")};Text("Text size, contrast and reduced motion follow your iPhone's accessibility settings.").font(.footnote).foregroundStyle(.secondary)}
        ClubPanel {Label("Your account stays protected",systemImage:"lock.shield").font(.headline);Text("Your session is stored in this device's Keychain. The app hides account content in the app switcher. Contact HOP for account or PIN changes.").font(.subheadline).foregroundStyle(.secondary)}
    }.navigationTitle("App preferences").navigationBarTitleDisplayMode(.inline).toolbar {ClubSheetClose()}}}
    private func appearance(_ title:String,id:String,symbol:String)->some View {Button {theme=id;ClubStyle.touch()}label:{VStack(spacing:12){Image(systemName:symbol).font(.title2);Text(title).font(.caption.bold());Image(systemName:theme == id ? "checkmark.circle.fill" : "circle").font(.subheadline)}.frame(maxWidth:.infinity).padding(.vertical,18).foregroundStyle(theme == id ? ClubStyle.accent : .secondary).background(theme == id ? ClubStyle.accent.opacity(0.10) : Color.secondary.opacity(0.04),in:RoundedRectangle(cornerRadius:17))}.buttonStyle(.plain).accessibilityLabel(title+" appearance").accessibilityAddTraits(theme == id ? [.isSelected] : [])}
}
struct ClubOrders:View {
    @EnvironmentObject var store:ClubStore
    var body:some View {ClubPage {
        ClubHeading(eyebrow:"YOUR PICKUPS",title:"Good food.\nGood memories.",subtitle:"Requests and purchases, all in one place.")
        if store.orders.isEmpty {ContentUnavailableView("No orders yet",systemImage:"bag",description:Text("Your pickup requests and completed purchases appear here."))}
        ForEach(store.orders){order in NavigationLink {ClubOrderDetail(orderID:order.id)}label:{ClubPanel {HStack {Text("Order #"+String(order.id.replacingOccurrences(of:"-",with:"").prefix(8)).uppercased()).font(.headline);Spacer();Text(ClubPolicy.money(order["total"].number)).font(.headline)};ClubPill(title:order["status"].text);Text(ClubPolicy.date(order["created_at"].text)).font(.caption).foregroundStyle(.secondary);Text("Pickup: "+order["pickup_time"].text).font(.subheadline)}}.buttonStyle(.plain)}
    }.navigationTitle("Your orders")}
}
struct ClubOrderDetail:View {
    @EnvironmentObject var store:ClubStore
    var orderID:String
    var order:J {store.orders.first {$0.id == orderID} ?? .null}
    var body:some View {ClubPage {
        ClubHeading(eyebrow:"YOUR ORDER",title:"We'll keep you posted.",subtitle:ClubPolicy.date(order["created_at"].text))
        ClubPanel {HStack {ClubIcon(symbol:"takeoutbag.and.cup.and.straw");VStack(alignment:.leading,spacing:6){Text("Pickup "+order["pickup_time"].text).font(.title2.bold());ClubPill(title:order["status"].text)}};Text("Pending requests require phone confirmation from a host before kitchen preparation.").font(.subheadline).foregroundStyle(.secondary);Label("Live restaurant status • pull down to refresh",systemImage:"arrow.clockwise").font(.caption).foregroundStyle(ClubStyle.accent)}
        ForEach(order["items"].array){item in ClubPanel {HStack {Text("\(item["quantity"].int) × "+item["name"].text).font(.headline);Spacer();Text(ClubPolicy.money(item["line_total"].number))};Text(item["size_label"].text).font(.caption).foregroundStyle(.secondary);ForEach(item["modifier_snapshot"]["summary"].array.map(\.text),id:\.self){Text($0).font(.caption)};if !item["notes"].text.isEmpty {Text(item["notes"].text).font(.caption)}}}
        ClubPanel {HStack {Text("Order total");Spacer();Text(ClubPolicy.money(order["total"].number))}.font(.title2.bold());Text("Payment at pickup · \(order["points_earned"].int) points recorded").font(.caption).foregroundStyle(.secondary)}
    }.navigationTitle("Order details").task {while !Task.isCancelled {await store.refresh();try? await Task.sleep(nanoseconds:30_000_000_000)}}}
}
struct ClubActivity:View {
    @EnvironmentObject var store:ClubStore
    var body:some View {ClubPage {
        ClubHeading(eyebrow:"YOUR HOP STORY",title:"Every visit adds up.")
        Text("Points and visits are credited by the connected system after validation—not by scanning this screen alone.").foregroundStyle(.secondary)
        ForEach(store.loyalty["ledger"].array){entry in ClubPanel {HStack {Text(entry["reason"].text.replacingOccurrences(of:"_",with:" ").capitalized).font(.headline);Spacer();Text((entry["points"].int>=0 ? "+" : "")+entry["points"].text+" pts").font(.headline).foregroundStyle(entry["points"].int<0 ? ClubStyle.red : ClubStyle.green)};Text(ClubPolicy.date(entry["created_at"].text)).font(.caption).foregroundStyle(.secondary)}}
        if store.loyalty["ledger"].array.isEmpty {ContentUnavailableView("No points activity yet",systemImage:"sparkles")}
    }.navigationTitle("Activity")}
}
