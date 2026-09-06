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
    var body:some View {VStack(alignment:.leading,spacing:0){ClubPhoto(path:entry["image_url"].text,height:185).clipShape(UnevenRoundedRectangle(topLeadingRadius:24,topTrailingRadius:24));VStack(alignment:.leading,spacing:10){Text(entry["name"].text).font(.title3.bold()).foregroundStyle(.primary);if !entry["description"].text.isEmpty {Text(entry["description"].text).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)};HStack {let sizes=ClubMenuRules.sizes(entry);Text((sizes.isEmpty ? "" : "From ")+ClubPolicy.money(sizes.first.map {entry["size_prices"][$0].number} ?? entry["price"].number)).font(.headline).foregroundStyle(ClubStyle.accent);Spacer();Image(systemName:"plus").font(.headline).foregroundStyle(.white).frame(width:36,height:36).background(ClubStyle.green,in:Circle())}}.padding(18)}.background(ClubStyle.surface,in:RoundedRectangle(cornerRadius:24)).overlay(RoundedRectangle(cornerRadius:24).stroke(.primary.opacity(0.05)))}
}
struct ClubItemEditor:View {
    @EnvironmentObject var store:ClubStore
    @Environment(\.dismiss) var dismiss
    var item:J
    @State private var size="Regular"
    @State private var quantity=1
    @State private var selections:[String:[J]]=[:]
    @State private var notes=""
    var validation:String? {ClubMenuRules.validation(item,size:size,selections:selections)}
    var body:some View {NavigationStack {ClubPage {
        ClubPhoto(path:item["image_url"].text,height:230)
        ClubHeading(eyebrow:"MAKE IT YOURS",title:item["name"].text,subtitle:item["description"].text)
        if !ClubMenuRules.sizes(item).isEmpty {ClubPanel {ClubSectionTitle(title:"Choose your size",detail:"Required");ForEach(ClubMenuRules.sizes(item),id:\.self){label in Button {ClubStyle.touch();size=label}label:{HStack {Image(systemName:size == label ? "checkmark.circle.fill" : "circle").font(.title3);Text(label).font(.headline);Spacer();Text(ClubPolicy.money(item["size_prices"][label].number)).font(.subheadline)}.foregroundStyle(size == label ? ClubStyle.accent : .primary).padding(14).frame(minHeight:48).background(size == label ? ClubStyle.accent.opacity(0.08) : Color.secondary.opacity(0.04),in:RoundedRectangle(cornerRadius:14))}.buttonStyle(.plain).accessibilityAddTraits(size == label ? [.isSelected] : [])}}}
        ForEach(ClubMenuRules.groups(item)){group in ClubPanel {
            HStack(alignment:.top){Text(group.first("customer_label","name")).font(.title3.bold());Spacer();ClubPill(title:group["required"].truth ? "Required" : "Optional",color:group["required"].truth ? ClubStyle.red : ClubStyle.accent)}
            ForEach(group["options"].array.filter {$0["is_active"] != .bool(false)}){option in optionRow(group,option)}
        }}
        ClubPanel {Stepper("Quantity: \(quantity)",value:$quantity,in:1...20).font(.headline);Divider();Text("Anything we should know?").font(.headline);TextField("Special instructions (optional)",text:$notes,axis:.vertical).lineLimit(3...5).padding(14).background(.secondary.opacity(0.06),in:RoundedRectangle(cornerRadius:14));Text("Final modifier prices, free selections, tax and fees are confirmed by HOP at checkout.").font(.caption).foregroundStyle(.secondary)}
        if store.pending != nil {Text("Resolve your pending request in Account before changing the order.").font(.subheadline).foregroundStyle(.orange)}
    }.navigationTitle("Your kind of delicious").navigationBarTitleDisplayMode(.inline).toolbar {ToolbarItem(placement:.topBarTrailing){ClubSheetClose()}}
    .safeAreaInset(edge:.bottom,spacing:0){VStack(spacing:10){if let validation {Text(validation).font(.caption).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading)};ClubAction(title:"Add \(quantity) to bag",symbol:"plus"){store.cart.append(ClubMenuRules.line(item,size:size,quantity:quantity,selections:selections,notes:notes));dismiss()}.disabled(validation != nil || store.pending != nil || store.busy)}.padding(18).background(.regularMaterial)}
    .task {size=ClubMenuRules.sizes(item).first ?? "Regular";selections=ClubMenuRules.defaults(item)}} }
    private func optionRow(_ group:J,_ option:J)->some View {
        let selected=selections[group.id]?.contains {$0["option_id"].text == option.id} ?? false
        return VStack(alignment:.leading,spacing:10) {
            Button {ClubStyle.touch();toggle(group,option,!selected)}label:{HStack(spacing:12){Image(systemName:selected ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(selected ? ClubStyle.accent : .secondary);Text(option["name"].text).font(.subheadline.weight(.medium)).foregroundStyle(.primary);Spacer();if option["price"].number>0 {Text("+"+ClubPolicy.money(option["price"].number)).font(.caption).foregroundStyle(.secondary)}}.padding(14).frame(minHeight:48).background(selected ? ClubStyle.accent.opacity(0.08) : Color.secondary.opacity(0.035),in:RoundedRectangle(cornerRadius:14))}.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
            if selected {
                if group["allow_half"].truth {Picker("Portion",selection:optionBinding(group,option,key:"portion",fallback:"whole")){Text("Whole").tag("whole");if option["allow_left"] != .bool(false){Text("Left half").tag("left")};if option["allow_right"] != .bool(false){Text("Right half").tag("right")}}}
                if group["supports_styles"].truth {Picker("Style",selection:optionBinding(group,option,key:"style",fallback:"regular")){Text("Regular").tag("regular");if option["available_as_extra"] != .bool(false){Text("Extra").tag("extra")};if option["available_as_light"].truth {Text("Light").tag("light")};if option["available_on_side"].truth {Text("On the side").tag("side")}}}
                if option["max_quantity"].int>1 {Picker("Amount",selection:optionBinding(group,option,key:"quantity",fallback:"1")){ForEach(1...min(10,option["max_quantity"].int),id:\.self){Text("\($0)").tag(String($0))}}}
            }
        }
    }
    private func toggle(_ group:J,_ option:J,_ enabled:Bool) {
        var values=selections[group.id] ?? []
        if enabled {if group["selection_type"].text == "single" {values=[]};values.removeAll {$0["option_id"].text == option.id};values.append(.object(["option_id":.s(option.id),"portion":.s("whole"),"style":.s("regular"),"quantity":.n(1)]))}else{values.removeAll {$0["option_id"].text == option.id}}
        selections[group.id]=values
    }
    private func optionBinding(_ group:J,_ option:J,key:String,fallback:String)->Binding<String> {Binding(get:{selections[group.id]?.first {$0["option_id"].text == option.id}?[key].text ?? fallback},set:{value in var values=selections[group.id] ?? [];if let index=values.firstIndex(where:{$0["option_id"].text == option.id}){values[index][key]=key == "quantity" ? .n(Int(value) ?? 1) : .s(value)};selections[group.id]=values})}
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
    var snapshot:String {J.array(store.cart).pretty+"|"+tip}
    var tipValue:Double? {Double(tip.replacingOccurrences(of:",",with:"."))}
    var body:some View {ClubPage {
        ClubHeading(eyebrow:"PICKUP AT HOP",title:"A bag full of good.",subtitle:"Review your choices. We'll take it from here.")
        if let pending=store.pending {ClubPanel {Label("Request needs checking",systemImage:"exclamationmark.circle").font(.headline);Text("The last response may not have arrived. Check your history before retrying. A retry uses the same request key.").foregroundStyle(.secondary);if pending["kind"].text == "order" {Button("Retry original pickup request"){Task {await store.place(.null)}}.disabled(store.busy)};NavigationLink("View account & history"){ClubAccount()}}}
        if store.cart.isEmpty {ContentUnavailableView("Your bag is empty",systemImage:"bag",description:Text("Choose something delicious from the menu."))}
        else {
            ForEach(store.cart){line in ClubPanel {HStack(alignment:.top,spacing:14){ClubPhoto(path:line["image_url"].text,height:72).frame(width:72);VStack(alignment:.leading,spacing:7){Text(line["name"].text).font(.headline);Text(line["size_label"].text).font(.caption).foregroundStyle(.secondary)};Spacer(minLength:0);Button(role:.destructive){store.cart.removeAll {$0.id == line.id}}label:{Image(systemName:"minus.circle").frame(width:36,height:36)}.accessibilityLabel("Remove "+line["name"].text).disabled(store.busy || store.pending != nil)};ForEach(Array(line["display_options"].array.enumerated()),id:\.offset){_,option in Text(option.text).font(.caption).foregroundStyle(.secondary)};Stepper("Quantity: \(line["quantity"].int)",value:Binding(get:{line["quantity"].int},set:{value in if let index=store.cart.firstIndex(where:{$0.id == line.id}){store.cart[index]["quantity"] = .n(value)}}),in:1...20).disabled(store.busy || store.pending != nil);if !line["notes"].text.isEmpty {Label(line["notes"].text,systemImage:"text.bubble").font(.caption).foregroundStyle(.secondary)}}}
            ClubPanel {ClubLinkRow(symbol:"takeoutbag.and.cup.and.straw",title:"Pickup at the restaurant",subtitle:"Pay when you arrive");Divider();Picker("Preferred pickup",selection:$pickup){ForEach(["ASAP","30 minutes","45 minutes","60 minutes"],id:\.self){Text($0)}};HStack {Text("Tip at pickup ($)");TextField("0.00",text:$tip).keyboardType(.decimalPad).multilineTextAlignment(.trailing).padding(12).background(.secondary.opacity(0.06),in:RoundedRectangle(cornerRadius:12))};TextField("Order notes (optional)",text:$notes,axis:.vertical).lineLimit(2...4).padding(14).background(.secondary.opacity(0.06),in:RoundedRectangle(cornerRadius:14))}.disabled(store.busy || store.pending != nil)
            ClubPanel {Text("All the details").font(.title3.bold());if quoting {ProgressView("Confirming prices with HOP…")}else if let quoteError {Text(quoteError).foregroundStyle(.red);Button("Retry quote"){Task {await loadQuote()}}}else if !pricing.isNull {totals};Text("This is a pickup request. A host must confirm by phone before the kitchen prepares your order.").font(.footnote).foregroundStyle(.secondary)}
        }
    }.navigationTitle("Your bag").navigationBarTitleDisplayMode(.inline).safeAreaInset(edge:.bottom,spacing:0){if !store.cart.isEmpty {ClubAction(title:store.busy ? "Sending request…" : "Review pickup request",symbol:"arrow.right"){confirm=true}.disabled(store.busy || quoting || pricing.isNull || store.pending != nil || !store.ordering).padding(18).background(.regularMaterial)}}.task(id:snapshot){await loadQuote()}.confirmationDialog("Send this pickup request for \(ClubPolicy.money(pricing["total"].number))? A host must confirm by phone.",isPresented:$confirm,titleVisibility:.visible){Button("Send pickup request"){let body:J = .object(["fulfillment_type":.s("pickup"),"pickup_time":.s(pickup),"tip":.number(tipValue ?? 0),"notes":.s(String(notes.prefix(800))),"pricing_token":pricing["pricing_token"],"items":.array(ClubMenuRules.requestItems(store.cart))]);Task {await store.place(body)}}} }
    private var totals:some View {VStack(spacing:12){sum("Food",pricing["item_subtotal"].number);if pricing["discount_total"].number>0 {sum("Discount",-pricing["discount_total"].number)};sum(pricing["tax_name"].text.isEmpty ? "Tax" : pricing["tax_name"].text,pricing["tax_total"].number);if pricing["fee_total"].number>0 {sum("Fees",pricing["fee_total"].number)};sum("Tip",pricing["tip_total"].number);Divider();HStack {Text("Total");Spacer();Text(ClubPolicy.money(pricing["total"].number))}.font(.title2.bold())}}
    private func sum(_ title:String,_ amount:Double)->some View {HStack {Text(title).foregroundStyle(.secondary);Spacer();Text(ClubPolicy.money(amount)).monospacedDigit()}}
    private func loadQuote() async {
        let ticket=snapshot;pricing = .null;quoteError=nil
        guard store.pending == nil,!store.cart.isEmpty else{return}
        guard let tipValue,tipValue.isFinite,tipValue>=0,tipValue<=1000 else{quoteError="Enter a tip between $0 and $1,000.";return}
        quoting=true;defer {if snapshot == ticket {quoting=false}}
        do {let result=try await store.quote(tip:tipValue);if !Task.isCancelled && snapshot == ticket {pricing=result}}
        catch {if !Task.isCancelled && snapshot == ticket {quoteError=error.localizedDescription}}
    }
}
