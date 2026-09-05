import SwiftUI

struct NativeInvoices:View {
    @EnvironmentObject var store:NativeStore
    @State private var search="",filter="All",opening=false
    @State private var editing:J?
    var records:[J] {store.items("/api/invoices","invoices").filter {($0.displayName+" "+$0.first("invoice_number","customer_name")).localizedCaseInsensitiveContains(search) || search.isEmpty}.filter {filter == "All" || $0["document_type"].text == filter.lowercased()}}
    var body:some View {NativeScreen(title:"Invoices & quotes",subtitle:"One workspace. Regular menu, catering and custom items, with an exact PDF preview.") {
        HStack {TextField("Search customer or document",text:$search).textFieldStyle(.roundedBorder); Picker("Type",selection:$filter) {Text("All").tag("All");Text("Invoice").tag("Invoice");Text("Quote").tag("Quote")}.pickerStyle(.segmented).frame(width:250);Button {editing=newDocument()} label:{Label("New document",systemImage:"plus")}.buttonStyle(.borderedProminent)}
        if opening {ProgressView("Opening complete invoice…")}
        if records.isEmpty {NativeEmpty(title:"No matching documents",icon:"doc.text")}
        LazyVGrid(columns:[GridItem(.adaptive(minimum:310))],spacing:16) {ForEach(records) {doc in Button {Task {opening=true;defer {opening=false};do {let result=try await store.api.request("/api/invoices/\(doc.id)");guard !result["invoice"].isNull else {throw NativeFailure(status:0,message:"The complete invoice could not be loaded.")};editing=result["invoice"]}catch {store.report(error)}}} label:{HOPPanel {HStack {Image(systemName:doc["document_type"].text == "quote" ? "doc.badge.clock" : "doc.text").font(.title2);Spacer();StatusTag(value:doc.statusText)};Text(doc["customer_name"].text).font(.title3.bold());Text(doc.first("invoice_number","document_number")).foregroundStyle(.secondary);HStack {Text(HOPDay.label(doc["issue_date"].text));Spacer();Text(HOPMoney.show(doc["total_cents"].int)).font(.title3.bold())}}.foregroundStyle(.primary)}.buttonStyle(.plain).disabled(opening)} }
    }.fullScreenCover(item:$editing) {NativeInvoiceStudio(original:$0)} }
    func newDocument()->J {.object(["id":.s("new"),"document_type":.s("invoice"),"status":.s("draft"),"issue_date":.s(HOPDay.today),"due_date":.s(HOPDay.add(HOPDay.today,7)),"event_date":.s(HOPDay.today),"items":.array([]),"tax_rate_basis_points":.n(800),"card_fee_basis_points":.n(350),"payment_method":.s("not-set")])}
}
struct NativeInvoiceStudio:View {
    @EnvironmentObject var store:NativeStore;@Environment(\.dismiss) var dismiss
    var original:J
    @State private var doc:J = .null
    @State private var catalog=false,preview=false,discard=false,archive=false
    @State private var changed=false
    var isNew:Bool {original.id == "new"}
    var document:NativeDocument {NativePDF.invoice(doc)}
    var locked:Bool {doc["is_locked"].truth || doc["locked"].truth}
    var body:some View {NavigationStack {GeometryReader {geometry in
        HStack(spacing:0) {Form {
            Section("Document") {RecordFields(record:$doc,fields:[.init(key:"document_type",title:"Type",kind:.choice(["invoice","quote"])),.init(key:"status",title:"Status",kind:.choice(["draft","sent","partial","paid","void"])),.init(key:"issue_date",title:"Issued",kind:.date),.init(key:"due_date",title:"Due",kind:.date),.init(key:"event_date",title:"Event date",kind:.date)])}
            Section("Customer") {RecordFields(record:$doc,fields:[.init(key:"customer_name",title:"Customer / organization"),.init(key:"contact_name",title:"Contact"),.init(key:"customer_phone",title:"Phone"),.init(key:"customer_email",title:"Email"),.init(key:"customer_address",title:"Billing / delivery address",kind:.paragraph)])}
            Section {ForEach(Array(doc["items"].array.enumerated()),id:\.offset) {index,item in invoiceLine(index,item)};HStack {Button {catalog=true} label:{Label("From menu",systemImage:"fork.knife")}.buttonStyle(.bordered);Button {append(.object(["description":.s(""),"quantity":.n(1),"unit_price_cents":.n(0),"source_type":.s("custom")]))} label:{Label("Custom line",systemImage:"plus")}.buttonStyle(.bordered)}} header:{Text("Items")} footer:{Text("Edit quantity, description and price directly. No typed separators or special formatting.")}
            Section("Pricing adjustments") {RecordFields(record:$doc,fields:[.init(key:"discount_cents",title:"Discount ($)",kind:.money),.init(key:"discount_basis_points",title:"Discount (%)",kind:.percent),.init(key:"tax_rate_basis_points",title:"Sales tax (%)",kind:.percent),.init(key:"delivery_fee_cents",title:"Delivery ($)",kind:.money),.init(key:"gratuity_cents",title:"Gratuity ($)",kind:.money),.init(key:"other_fee_cents",title:"Other charge ($)",kind:.money),.init(key:"card_fee_basis_points",title:"Card fee (%)",kind:.percent),.init(key:"amount_paid_cents",title:"Amount paid ($)",kind:.money),.init(key:"payment_method",title:"Payment",kind:.choice(["not-set","cash","check","card","online"]))]);Text("Delivery appears as a clearly labeled charge in the totals. Do not also add it as an item.").font(.footnote).foregroundStyle(.secondary)}
            Section("Notes") {RecordFields(record:$doc,fields:[.init(key:"customer_note",title:"Customer note (printed)",kind:.paragraph),.init(key:"internal_note",title:"Internal note (not printed)",kind:.paragraph)])}
            if !isNew {Section {Button("Archive document",role:.destructive){archive=true}}}
        }.disabled(locked || store.saving).frame(width:geometry.size.width>1000 ? geometry.size.width*0.49 : geometry.size.width)
        if geometry.size.width>1000 {Divider();VStack(spacing:0) {HStack {Label("Live print preview",systemImage:"doc.richtext").font(.headline);Spacer();Text("US Letter · Portrait").font(.caption).foregroundStyle(.secondary)}.padding(18);NativePDFCanvas(data:document.data)}}
    }}.navigationTitle(isNew ? "New document" : original.first("invoice_number","document_number")).navigationBarTitleDisplayMode(.inline).toolbar {
        ToolbarItem(placement:.cancellationAction){Button("Close"){if changed {discard=true}else {dismiss()}}}
        ToolbarItemGroup(placement:.primaryAction){Button {preview=true} label:{Label("Preview / export",systemImage:"square.and.arrow.up")}.disabled(doc["items"].array.isEmpty);Button("Save"){save()}.buttonStyle(.borderedProminent).disabled(store.saving || locked || doc["customer_name"].text.isEmpty || doc["items"].array.isEmpty)}
    }.task {doc=original;changed=false}.onChange(of:doc) {old,new in if old != .null && old != new {changed=true}}
    .sheet(isPresented:$catalog) {NativeInvoiceCatalog {append($0)}}
    .sheet(isPresented:$preview){NativeDocumentPreview(document:document)}
    .confirmationDialog("Discard unsaved changes?",isPresented:$discard,titleVisibility:.visible){Button("Discard",role:.destructive){dismiss()}}
    .confirmationDialog("Archive this document? It remains in the existing database history.",isPresented:$archive,titleVisibility:.visible){Button("Archive",role:.destructive){Task {do {_ = try await store.send("/api/invoices/\(doc.id)/archive",body:.object(["archived":.bool(true),"actor_id":.s(store.manager.id)]));await store.load();dismiss()}catch {store.report(error)}}}}
    }.interactiveDismissDisabled(changed) }
    private func invoiceLine(_ index:Int,_ item:J)->some View {VStack(alignment:.leading,spacing:12) {
        TextField("Item name / description",text:binding(index,"description")).font(.headline)
        HStack {VStack(alignment:.leading) {Text("Qty").font(.caption).foregroundStyle(.secondary);TextField("1",text:binding(index,"quantity")).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).frame(width:60)};VStack(alignment:.leading) {Text("Unit price").font(.caption).foregroundStyle(.secondary);TextField("0.00",text:Binding(get:{HOPMoney.dollars(item["unit_price_cents"].int)},set:{update(index,"unit_price_cents",.n(HOPMoney.cents($0)))})).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).frame(width:100)};Spacer();Text(HOPMoney.show(HOPMoney.round(item["quantity"].number*item["unit_price_cents"].number))).bold();Button(role:.destructive){var items=doc["items"].array;items.remove(at:index);doc["items"] = .array(items)}label:{Image(systemName:"trash")}.buttonStyle(.borderless).accessibilityLabel("Remove \(item["description"].text)")}
    }.padding(.vertical,8) }
    private func binding(_ index:Int,_ key:String)->Binding<String> {Binding(get:{doc["items"].array.indices.contains(index) ? doc["items"].array[index][key].text : ""},set:{update(index,key,key == "quantity" ? .number(Double($0) ?? 0) : .s($0))})}
    private func update(_ index:Int,_ key:String,_ value:J) {var items=doc["items"].array;guard items.indices.contains(index) else {return};items[index][key]=value;doc["items"] = .array(items)}
    private func append(_ line:J) {doc["items"] = .array(doc["items"].array+[line.set(["sort_order":.n(doc["items"].array.count)])])}
    private func save() {guard doc["items"].array.allSatisfy({!$0["description"].text.trimmingCharacters(in:.whitespaces).isEmpty && $0["quantity"].number>0 && $0["unit_price_cents"].number>=0}) else {store.error="Each item needs a name, a positive quantity and a valid non-negative price.";return};Task {do {var payload=doc;payload["actor_id"] = .s(store.manager.id);payload["id"] = isNew ? .null : doc["id"];let result=try await store.send(isNew ? "/api/invoices" : "/api/invoices/\(original.id)",method:isNew ? "POST" : "PUT",body:payload);guard !result["invoice"].isNull else {throw NativeFailure(status:0,message:"The server did not confirm the saved document.")};await store.load();changed=false;dismiss()}catch {store.report(error)}}}
}
struct NativeInvoiceCatalog:View {
    @EnvironmentObject var store:NativeStore;@Environment(\.dismiss) var dismiss
    var add:(J)->Void
    @State private var category="Regular",search=""
    var menu:[J] {store.items("/api/menu/items","items","menu_items").filter {item in let cat=store.items("/api/menu/categories","categories").first {$0.id == item["category_id"].text};let catering=(item.first("category_name","category_slug")+" "+(cat?.first("slug","name") ?? "")).lowercased().contains("cater");return (category == "Catering" ? catering : !catering) && (search.isEmpty || item["name"].text.localizedCaseInsensitiveContains(search))}}
    var body:some View {NavigationStack {List {Section {Picker("Menu",selection:$category){Text("Regular menu").tag("Regular");Text("Catering menu").tag("Catering")}.pickerStyle(.segmented)};ForEach(menu) {item in
        let sizes=item["size_prices"].object.sorted {$0.key<$1.key}
        if sizes.isEmpty {Button {choose(item,price:item["price"].number,name:item["name"].text)}label:{HStack {NativePhoto(path:item["image_url"].text,size:48);Text(item["name"].text);Spacer();Text(HOPMoney.show(HOPMoney.round(item["price"].number*100)))}}}
        else {DisclosureGroup(item["name"].text){ForEach(sizes,id:\.key){size in Button {choose(item,price:size.value.number,name:item["name"].text+" · "+size.key)}label:{HStack {Text(size.key.capitalized);Spacer();Text(HOPMoney.show(HOPMoney.round(size.value.number*100)))}}}}}
    }}.searchable(text:$search,prompt:"Find a menu item").navigationTitle("Add menu item").toolbar {Button("Done"){dismiss()}}} }
    private func choose(_ item:J,price:Double,name:String) {add(.object(["description":.s(name),"quantity":.n(1),"unit_price_cents":.n(HOPMoney.round(price*100)),"source_id":.s(item.id),"source_type":.s("menu")]));dismiss()}
}
