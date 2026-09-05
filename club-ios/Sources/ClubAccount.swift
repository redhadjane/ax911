import SwiftUI

struct ClubAccount:View {
    @EnvironmentObject var store:ClubStore
    @AppStorage("hop.club.appearance") private var theme="system"
    @State private var logout=false
    @State private var clear=false
    var body:some View {ClubPage {
        ClubPanel {HStack {Image(systemName:"person.crop.circle.fill").font(.system(size:48)).foregroundStyle(ClubStyle.green);VStack(alignment:.leading,spacing:6){Text(store.customer["name"].text).font(.title2.bold());Text(store.customer["phone"].text).foregroundStyle(.secondary)}};Text("Your profile is shared with the restaurant's existing HOP Club system.").font(.footnote).foregroundStyle(.secondary)}
        if let pending=store.pending {ClubPanel {Label("A request needs your review",systemImage:"exclamationmark.triangle").font(.headline).foregroundStyle(.orange);Text("A response may have been interrupted. Check order and reward history first. Retry keeps the original request key to prevent duplicates.");if pending["kind"].text == "order" {NavigationLink("Review pickup request"){ClubCart()}}else{Button("Retry same reward request"){Task {_ = await store.redeem(.object(["id":pending["body"]["reward_rule_id"]]))}}};Button("I reviewed history — clear pending request",role:.destructive){clear=true}.disabled(store.busy)}}
        ClubPanel {NavigationLink {ClubOrders()}label:{Label("Orders & pickup status",systemImage:"bag")};Divider();NavigationLink {ClubActivity()}label:{Label("Points & reward activity",systemImage:"sparkles")};Divider();Button {store.tab="rewards"}label:{Label("Reward requests",systemImage:"gift")}}
        ClubPanel {Text("Make yourself at home").font(.title3.bold());Picker("Appearance",selection:$theme){Text("System").tag("system");Text("Light").tag("light");Text("Dark").tag("dark")}.pickerStyle(.segmented);Text("Text size and reduced motion follow your iPhone's accessibility settings.").font(.caption).foregroundStyle(.secondary)}
        ClubPanel {Label("Notifications",systemImage:"bell").font(.headline);Text("Pull down to refresh offers, points and order status. This SideStore test build does not support background push. No pretend push switch is enabled.").font(.subheadline).foregroundStyle(.secondary)}
        ClubPanel {Text("Need a hand?").font(.headline);Text("Contact the restaurant for profile corrections, PIN help, or questions about a ticket or reward.").foregroundStyle(.secondary);Link("Restaurant website",destination:URL(string:ClubPolicy.origin)!);Text("Native HOP Club · 0.1.0 (1)").font(.caption).foregroundStyle(.secondary);if let sync=store.lastSync {Text("Updated \(sync.formatted(date:.omitted,time:.shortened))").font(.caption).foregroundStyle(.secondary)}}
        Button("Sign out",role:.destructive){logout=true}.buttonStyle(.bordered).disabled(store.busy)
    }.navigationTitle("Your account").confirmationDialog("Sign out of this iPhone? Your account stays with HOP.",isPresented:$logout,titleVisibility:.visible){Button("Sign out",role:.destructive){store.logout()}}.confirmationDialog("Only clear this after checking history. Clearing does not cancel an order or reward already received by HOP.",isPresented:$clear,titleVisibility:.visible){Button("Clear pending request",role:.destructive){store.clearPendingAfterReview()}}}
}
struct ClubOrders:View {
    @EnvironmentObject var store:ClubStore
    var body:some View {ClubPage {
        if store.orders.isEmpty {ContentUnavailableView("No orders yet",systemImage:"bag",description:Text("Your pickup requests and completed purchases appear here."))}
        ForEach(store.orders){order in NavigationLink {ClubOrderDetail(orderID:order.id)}label:{ClubPanel {HStack {Text("Order #"+String(order.id.replacingOccurrences(of:"-",with:"").prefix(8)).uppercased()).font(.headline);Spacer();Text(ClubPolicy.money(order["total"].number)).font(.headline)};ClubPill(title:order["status"].text);Text(ClubPolicy.date(order["created_at"].text)).font(.caption).foregroundStyle(.secondary);Text("Pickup: "+order["pickup_time"].text).font(.subheadline)}}.buttonStyle(.plain)}
    }.navigationTitle("Your orders")}
}
struct ClubOrderDetail:View {
    @EnvironmentObject var store:ClubStore
    var orderID:String
    var order:J {store.orders.first {$0.id == orderID} ?? .null}
    var body:some View {ClubPage {
        ClubPanel {ClubPill(title:order["status"].text);Text("Pickup "+order["pickup_time"].text).font(.title2.bold());Text("Pending requests require phone confirmation from a host before kitchen preparation.").font(.subheadline).foregroundStyle(.secondary);Text(ClubPolicy.date(order["created_at"].text)).font(.caption)}
        ForEach(order["items"].array){item in ClubPanel {HStack {Text("\(item["quantity"].int) × "+item["name"].text).font(.headline);Spacer();Text(ClubPolicy.money(item["line_total"].number))};Text(item["size_label"].text).font(.caption).foregroundStyle(.secondary);ForEach(item["modifier_snapshot"]["summary"].array.map(\.text),id:\.self){Text($0).font(.caption)};if !item["notes"].text.isEmpty {Text(item["notes"].text).font(.caption)}}}
        ClubPanel {HStack {Text("Order total");Spacer();Text(ClubPolicy.money(order["total"].number))}.font(.title2.bold());Text("Payment at pickup · \(order["points_earned"].int) points recorded").font(.caption).foregroundStyle(.secondary)}
    }.navigationTitle("Order details").task {while !Task.isCancelled {await store.refresh();try? await Task.sleep(nanoseconds:30_000_000_000)}}}
}
struct ClubActivity:View {
    @EnvironmentObject var store:ClubStore
    var body:some View {ClubPage {
        Text("Your HOP story").font(.largeTitle.bold())
        Text("Points and visits are credited by the connected system after validation—not by scanning this screen alone.").foregroundStyle(.secondary)
        ForEach(store.loyalty["ledger"].array){entry in ClubPanel {HStack {Text(entry["reason"].text.replacingOccurrences(of:"_",with:" ").capitalized).font(.headline);Spacer();Text((entry["points"].int>=0 ? "+" : "")+entry["points"].text+" pts").font(.headline).foregroundStyle(entry["points"].int<0 ? ClubStyle.red : ClubStyle.green)};Text(ClubPolicy.date(entry["created_at"].text)).font(.caption).foregroundStyle(.secondary)}}
        if store.loyalty["ledger"].array.isEmpty {ContentUnavailableView("No points activity yet",systemImage:"sparkles")}
    }.navigationTitle("Activity")}
}
