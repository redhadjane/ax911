import SwiftUI

struct ClubMenu:View {
    @EnvironmentObject var store:ClubStore
    @State private var search=""
    @State private var category="all"
    @State private var item:J?
    var items:[J] {store.menu["items"].array.filter {item in item["is_active"] != .bool(false) && (category == "all" || item["category_id"].text == category) && (search.isEmpty || (item["name"].text+" "+item["description"].text).localizedCaseInsensitiveContains(search))}}
    var body:some View {ClubPage {
        ClubHeading(eyebrow:"MADE HERE. LOVED HERE.",title:"What sounds good?",subtitle:"Your next favorite is on the menu.")
        ScrollView(.horizontal){HStack(spacing:9){categoryButton("All dishes",id:"all");ForEach(store.menu["categories"].array){entry in categoryButton(entry["name"].text,id:entry.id)}}.padding(.vertical,3)}.scrollIndicators(.hidden)
        if store.menu.isNull {ContentUnavailableView("Menu hasn't loaded",systemImage:"wifi.exclamationmark",description:Text("Pull down to try again."))}
        else if items.isEmpty {ContentUnavailableView.search(text:search)}
        ClubSectionTitle(title:category == "all" ? "The menu" : (store.menu["categories"].array.first {$0.id == category}?["name"].text ?? "Menu"),detail:"\(items.count) dishes")
        LazyVStack(spacing:16) {ForEach(items){entry in Button {ClubStyle.touch();item=entry}label:{ClubMenuTile(entry:entry)}.buttonStyle(ClubPressStyle())}}
    }.navigationTitle("Menu").navigationBarTitleDisplayMode(.inline).searchable(text:$search,prompt:"Pizza, pasta, something good…")
    .toolbar {NavigationLink {ClubCart()}label:{Label("\(store.cart.reduce(0){$0+$1["quantity"].int})",systemImage:"bag")}.accessibilityLabel("Your bag, \(store.cart.reduce(0){$0+$1["quantity"].int}) items")}
    .safeAreaInset(edge:.bottom,spacing:0){if !store.cart.isEmpty {NavigationLink {ClubCart()}label:{HStack {Text("\(store.cart.reduce(0){$0+$1["quantity"].int})").font(.headline).frame(width:34,height:34).background(.white.opacity(0.15),in:RoundedRectangle(cornerRadius:11));Text("Your bag is looking good").font(.subheadline.bold());Spacer();Image(systemName:"arrow.right")}.foregroundStyle(.white).padding(15).background(ClubStyle.green,in:RoundedRectangle(cornerRadius:22))}.buttonStyle(ClubPressStyle()).padding(.horizontal,20).padding(.vertical,10).background(.regularMaterial)}}
    .sheet(item:$item){ClubItemEditor(item:$0).presentationDragIndicator(.visible).presentationCornerRadius(32)} }
    private func categoryButton(_ title:String,id:String)->some View {Button {ClubStyle.touch();category=id}label:{Text(title).font(.subheadline.weight(.semibold)).padding(.horizontal,18).padding(.vertical,13).foregroundStyle(category == id ? Color.white : ClubStyle.accent).background(category == id ? ClubStyle.green : ClubStyle.surface,in:Capsule())}.buttonStyle(ClubPressStyle()).accessibilityAddTraits(category == id ? [.isSelected] : [])}
}
struct ClubMenuTile:View {
    var entry:J
    var body:some View {VStack(alignment:.leading,spacing:0){ClubDishArt(item:entry).frame(height:185).clipShape(UnevenRoundedRectangle(topLeadingRadius:24,topTrailingRadius:24));VStack(alignment:.leading,spacing:10){Text(entry["name"].text).font(.title3.bold()).foregroundStyle(.primary);if !entry["description"].text.isEmpty {Text(entry["description"].text).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)};HStack {let sizes=ClubMenuRules.sizes(entry);Text((sizes.isEmpty ? "" : "From ")+ClubPolicy.money(sizes.first.map {entry["size_prices"][$0].number} ?? entry["price"].number)).font(.headline).foregroundStyle(ClubStyle.accent);Spacer();Image(systemName:"plus").font(.headline).foregroundStyle(.white).frame(width:36,height:36).background(ClubStyle.green,in:Circle())}}.padding(18)}.background(ClubStyle.surface,in:RoundedRectangle(cornerRadius:24)).overlay(RoundedRectangle(cornerRadius:24).stroke(.primary.opacity(0.05)))}
}
struct ClubCart:View {
    @EnvironmentObject var store:ClubStore
    @State private var tip="0"
    @State private var notes=""
    @State private var pickup="ASAP"
    @State private var pricing:J = .null
    @State private var quoteError:String?
    @State private var quoting=false
    @State private var confirm=false
    @State private var editing:J?
    @State private var receipt:J?
    var snapshot:String {J.array(store.cart).pretty+"|"+tip}
    var tipValue:Double? {Double(tip.replacingOccurrences(of:",",with:"."))}
    var body:some View {ClubPage {
        ClubHeading(eyebrow:"PICKUP AT HOP",title:"A bag full of good.",subtitle:"Review your choices. We'll take it from here.")
        if let pending=store.pending {ClubPanel {Label("Request needs checking",systemImage:"exclamationmark.circle").font(.headline);Text("The last response may not have arrived. Check your history before retrying. A retry uses the same request key.").foregroundStyle(.secondary);if pending["kind"].text == "order" {Button("Retry original pickup request"){Task {await store.place(.null)}}.disabled(store.busy)};NavigationLink("View account & history"){ClubAccount()}}}
        if store.cart.isEmpty {ContentUnavailableView("Your bag is empty",systemImage:"bag",description:Text("Choose something delicious from the menu."))}
        else {
            ForEach(store.cart){line in ClubPanel {HStack(alignment:.top,spacing:14){ClubDishArt(item:store.menu["items"].array.first {$0.id == line["menu_item_id"].text} ?? line,selections:ClubBuilder.selections(line)).frame(width:72,height:72).clipped();VStack(alignment:.leading,spacing:7){Text(line["name"].text).font(.headline);Text(line["size_label"].text).font(.caption).foregroundStyle(.secondary);Button("Edit choices",systemImage:"slider.horizontal.3"){editing=line}.font(.subheadline).frame(minHeight:44).disabled(store.busy || store.pending != nil)};Spacer(minLength:0);Button(role:.destructive){store.cart.removeAll {$0.id == line.id}}label:{Image(systemName:"minus.circle").frame(width:44,height:44)}.accessibilityLabel("Remove "+line["name"].text).disabled(store.busy || store.pending != nil)};ForEach(Array(line["display_options"].array.enumerated()),id:\.offset){_,option in Text(option.text).font(.caption).foregroundStyle(.secondary)};Stepper("Quantity: \(line["quantity"].int)",value:Binding(get:{line["quantity"].int},set:{value in if let index=store.cart.firstIndex(where:{$0.id == line.id}){store.cart[index]["quantity"] = .n(value)}}),in:1...20).disabled(store.busy || store.pending != nil);if !line["notes"].text.isEmpty {Label(line["notes"].text,systemImage:"text.bubble").font(.caption).foregroundStyle(.secondary)}}}
            ClubPanel {ClubLinkRow(symbol:"takeoutbag.and.cup.and.straw",title:"Pickup at the restaurant",subtitle:"Pay when you arrive",chevron:false);Divider();Picker("Preferred pickup",selection:$pickup){ForEach(["ASAP","30 minutes","45 minutes","60 minutes"],id:\.self){Text($0)}};HStack {Text("Tip at pickup ($)");TextField("0.00",text:$tip).keyboardType(.decimalPad).multilineTextAlignment(.trailing).padding(12).background(.secondary.opacity(0.06),in:RoundedRectangle(cornerRadius:12))};TextField("Order notes (optional)",text:$notes,axis:.vertical).lineLimit(2...4).padding(14).background(.secondary.opacity(0.06),in:RoundedRectangle(cornerRadius:14))}.disabled(store.busy || store.pending != nil)
            ClubPanel {ClubLinkRow(symbol:"creditcard",title:"Payment",subtitle:"Pay at pickup",chevron:false);Text("Nothing is charged in this app. Online payments, including Apple Pay, are not enabled yet.").font(.subheadline).foregroundStyle(.secondary);if !store.customer["phone"].text.isEmpty {Label("Host confirmation: "+store.customer["phone"].text,systemImage:"phone").font(.caption).foregroundStyle(.secondary)}}
            ClubPanel {Text("All the details").font(.title3.bold());if quoting {ProgressView("Confirming prices with HOP…")}else if let quoteError {Text(quoteError).foregroundStyle(.red);Button("Retry quote"){Task {await loadQuote()}}}else if !pricing.isNull {totals};Text("This is a pickup request. A host must confirm by phone before the kitchen prepares your order.").font(.footnote).foregroundStyle(.secondary)}
        }
    }.navigationTitle("Your bag").navigationBarTitleDisplayMode(.inline).safeAreaInset(edge:.bottom,spacing:0){if !store.cart.isEmpty {ClubAction(title:store.busy ? "Sending request…" : "Review pickup request",symbol:"arrow.right"){confirm=true}.disabled(store.busy || quoting || pricing.isNull || store.pending != nil || !store.ordering).padding(18).background(.regularMaterial)}}.task(id:snapshot){await loadQuote()}.confirmationDialog("Send this pickup request for \(ClubPolicy.money(pricing["total"].number))? Pay at pickup. A host must confirm by phone.",isPresented:$confirm,titleVisibility:.visible){Button("Send pickup request"){let body:J = .object(["fulfillment_type":.s("pickup"),"pickup_time":.s(pickup),"tip":.number(tipValue ?? 0),"notes":.s(String(notes.prefix(800))),"pricing_token":pricing["pricing_token"],"items":.array(ClubMenuRules.requestItems(store.cart))]);Task {receipt=await store.place(body)}}}
        .sheet(item:$editing){line in if let item=store.menu["items"].array.first(where:{$0.id == line["menu_item_id"].text}) {ClubItemEditor(item:item,existing:line).presentationDragIndicator(.visible).presentationCornerRadius(32)}else{ContentUnavailableView("This item is no longer on the menu",systemImage:"fork.knife",description:Text("Remove it from the bag and choose an available dish."))}}
        .sheet(item:$receipt){order in ClubOrderReceipt(order:order).presentationDetents([.large]).presentationDragIndicator(.visible)} }
    private var totals:some View {VStack(spacing:12){sum("Food",pricing["item_subtotal"].number);if pricing["discount_total"].number>0 {sum("Discount",-pricing["discount_total"].number)};sum(pricing["tax_name"].text.isEmpty ? "Tax" : pricing["tax_name"].text,pricing["tax_total"].number);if pricing["fee_total"].number>0 {sum("Fees",pricing["fee_total"].number)};sum("Tip",pricing["tip_total"].number);Divider();HStack {Text("Total");Spacer();Text(ClubPolicy.money(pricing["total"].number))}.font(.title2.bold())}}
    private func sum(_ title:String,_ amount:Double)->some View {HStack {Text(title).foregroundStyle(.secondary);Spacer();Text(ClubPolicy.money(amount)).monospacedDigit()}}
    private func loadQuote() async {
        let ticket=snapshot;pricing = .null;quoteError=nil
        guard store.pending == nil,!store.cart.isEmpty else{quoting=false;return}
        guard let tipValue,tipValue.isFinite,tipValue>=0,tipValue<=1000 else{quoteError="Enter a tip between $0 and $1,000.";return}
        quoting=true;defer {if snapshot == ticket {quoting=false}}
        do {let result=try await store.quote(tip:tipValue);if !Task.isCancelled && snapshot == ticket {pricing=result}}
        catch {if !Task.isCancelled && snapshot == ticket {quoteError=error.localizedDescription}}
    }
}
