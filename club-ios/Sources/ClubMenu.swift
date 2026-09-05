import SwiftUI

struct ClubMenu:View {
    @EnvironmentObject var store:ClubStore
    @State private var search=""
    @State private var category="all"
    @State private var item:J?
    var items:[J] {store.menu["items"].array.filter {item in item["is_active"] != .bool(false) && (category == "all" || item["category_id"].text == category) && (search.isEmpty || (item["name"].text+" "+item["description"].text).localizedCaseInsensitiveContains(search))}}
    var body:some View {ClubPage {
        Text("Made for your cravings.").font(.largeTitle.bold())
        Picker("Category",selection:$category){Text("All dishes").tag("all");ForEach(store.menu["categories"].array){Text($0["name"].text).tag($0.id)}}.pickerStyle(.menu)
        if store.menu.isNull {ContentUnavailableView("Menu hasn't loaded",systemImage:"wifi.exclamationmark",description:Text("Pull down to try again."))}
        else if items.isEmpty {ContentUnavailableView.search(text:search)}
        LazyVStack(spacing:18) {ForEach(items){entry in Button {item=entry}label:{ClubPanel {
            ClubPhoto(path:entry["image_url"].text,height:170)
            HStack(alignment:.top){Text(entry["name"].text).font(.title3.bold());Spacer();let sizes=ClubMenuRules.sizes(entry);Text((sizes.isEmpty ? "" : "From ")+ClubPolicy.money(sizes.first.map {entry["size_prices"][$0].number} ?? entry["price"].number)).font(.headline).foregroundStyle(ClubStyle.green)}
            Text(entry["description"].text).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            Label("Choose options",systemImage:"plus.circle.fill").font(.subheadline.bold()).foregroundStyle(ClubStyle.green)
        }}.buttonStyle(.plain)}}
    }.navigationTitle("Menu").navigationBarTitleDisplayMode(.inline).searchable(text:$search,prompt:"Pizza, pasta, something good…")
    .toolbar {NavigationLink {ClubCart()}label:{Label("\(store.cart.reduce(0){$0+$1["quantity"].int})",systemImage:"bag")}}
    .sheet(item:$item){ClubItemEditor(item:$0)} }
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
    var body:some View {NavigationStack {Form {
        Section {ClubPhoto(path:item["image_url"].text,height:190);Text(item["description"].text).foregroundStyle(.secondary)}
        if !ClubMenuRules.sizes(item).isEmpty {Section("Size"){Picker("Choose size",selection:$size){ForEach(ClubMenuRules.sizes(item),id:\.self){label in Text(label+" · "+ClubPolicy.money(item["size_prices"][label].number)).tag(label)}}}}
        ForEach(ClubMenuRules.groups(item)){group in Section {
            if group["required"].truth {Text("Required").font(.caption.bold()).foregroundStyle(ClubStyle.red)}
            ForEach(group["options"].array.filter {$0["is_active"] != .bool(false)}){option in optionRow(group,option)}
        } header:{Text(group.first("customer_label","name"))}}
        Section {Stepper("Quantity: \(quantity)",value:$quantity,in:1...20);TextField("Special instructions",text:$notes,axis:.vertical).lineLimit(3...5);Text("Modifier prices, any free selections, tax and fees are calculated by the restaurant's server at checkout.").font(.caption).foregroundStyle(.secondary)}
        if let validation {Section {Text(validation).foregroundStyle(.orange)}}
        if store.pending != nil {Section {Text("Resolve your pending request in Account before changing the order.").foregroundStyle(.orange)}}
    }.navigationTitle(item["name"].text).navigationBarTitleDisplayMode(.inline).toolbar {
        ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
        ToolbarItem(placement:.confirmationAction){Button("Add to bag"){store.cart.append(ClubMenuRules.line(item,size:size,quantity:quantity,selections:selections,notes:notes));dismiss()}.disabled(validation != nil || store.pending != nil)}
    }.task {size=ClubMenuRules.sizes(item).first ?? "Regular";selections=ClubMenuRules.defaults(item)}} }
    private func optionRow(_ group:J,_ option:J)->some View {
        let selected=selections[group.id]?.contains {$0["option_id"].text == option.id} ?? false
        return VStack(alignment:.leading,spacing:10) {
            Toggle(isOn:Binding(get:{selected},set:{toggle(group,option,$0)})){HStack {Text(option["name"].text);Spacer();if option["price"].number>0 {Text("+"+ClubPolicy.money(option["price"].number)).font(.caption).foregroundStyle(.secondary)}}}.tint(ClubStyle.green)
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
        if let pending=store.pending {ClubPanel {Label("Request needs checking",systemImage:"exclamationmark.circle").font(.headline);Text("The last response may not have arrived. Check your history before retrying. A retry uses the same request key.").foregroundStyle(.secondary);if pending["kind"].text == "order" {Button("Retry original pickup request"){Task {await store.place(.null)}}.disabled(store.busy)};NavigationLink("View account & history"){ClubAccount()}}}
        if store.cart.isEmpty {ContentUnavailableView("Your bag is empty",systemImage:"bag",description:Text("Choose something delicious from the menu."))}
        else {
            ForEach(store.cart){line in ClubPanel {HStack {VStack(alignment:.leading,spacing:7){Text(line["name"].text).font(.headline);Text(line["size_label"].text).font(.caption).foregroundStyle(.secondary)};Spacer();Button(role:.destructive){store.cart.removeAll {$0.id == line.id}}label:{Image(systemName:"trash")}.disabled(store.busy || store.pending != nil)};Stepper("Quantity: \(line["quantity"].int)",value:Binding(get:{line["quantity"].int},set:{value in if let index=store.cart.firstIndex(where:{$0.id == line.id}){store.cart[index]["quantity"] = .n(value)}}),in:1...20).disabled(store.busy || store.pending != nil);if !line["notes"].text.isEmpty {Text(line["notes"].text).font(.caption).foregroundStyle(.secondary)}}}
            ClubPanel {Text("Pickup details").font(.title3.bold());Picker("Pickup time",selection:$pickup){ForEach(["ASAP","30 minutes","45 minutes","60 minutes"],id:\.self){Text($0)}};HStack {Text("Tip at pickup ($)");TextField("0.00",text:$tip).keyboardType(.decimalPad).multilineTextAlignment(.trailing)};TextField("Order notes",text:$notes,axis:.vertical).lineLimit(2...4)}.disabled(store.busy || store.pending != nil)
            ClubPanel {Text("Your order quote").font(.title3.bold());if quoting {ProgressView("Confirming prices with HOP…")}else if let quoteError {Text(quoteError).foregroundStyle(.red);Button("Retry quote"){Task {await loadQuote()}}}else if !pricing.isNull {totals};Text("Pay at pickup. This is a request—not a confirmed kitchen order. A host will confirm by phone.").font(.footnote).foregroundStyle(.secondary);ClubAction(title:"Review pickup request",symbol:"bag.badge.plus"){confirm=true}.disabled(store.busy || quoting || pricing.isNull || store.pending != nil || !store.ordering)}
        }
    }.navigationTitle("Your bag").task(id:snapshot){await loadQuote()}.confirmationDialog("Send this pickup request for \(ClubPolicy.money(pricing["total"].number))? A host must confirm by phone.",isPresented:$confirm,titleVisibility:.visible){Button("Send pickup request"){let body:J = .object(["fulfillment_type":.s("pickup"),"pickup_time":.s(pickup),"tip":.number(tipValue ?? 0),"notes":.s(String(notes.prefix(800))),"pricing_token":pricing["pricing_token"],"items":.array(ClubMenuRules.requestItems(store.cart))]);Task {await store.place(body)}}} }
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
