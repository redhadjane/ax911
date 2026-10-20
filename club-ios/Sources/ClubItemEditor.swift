import SwiftUI

private struct ClubOptionFocus: Identifiable { let group:J; let option:J; var id:String { group.id+"|"+option.id } }
struct ClubItemEditor: View {
    @EnvironmentObject private var store:ClubStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduced
    let item:J
    var existing:J? = nil
    @State private var size="Regular"
    @State private var notes=""
    @State private var step=0
    @State private var quantity=1
    @State private var selections:[String:[J]]=[:]
    @State private var initialized=false
    @State private var added=false
    @State private var quoting=false
    @State private var pricing:J = .null
    @State private var quoteError:String?
    @State private var focus:ClubOptionFocus?
    private var steps:[ClubBuildStep] { ClubBuilder.steps(item) }
    private var current:ClubBuildStep { steps[min(step,steps.count-1)] }
    private var validation:String? { ClubMenuRules.validation(item,size:size,selections:selections) }
    private var line:J { ClubMenuRules.line(item,size:size,quantity:quantity,selections:selections,notes:notes) }
    private var signature:String { size+"|"+String(quantity)+"|"+J.object(selections.mapValues(J.array)).pretty }
    private var baseNames:String { ClubMenuRules.groups(item).filter { !ClubBuilder.toppingGroup($0) }.flatMap { group in (selections[group.id] ?? []).compactMap { choice in group["options"].array.first { $0.id == choice["option_id"].text }?["name"].text } }.joined(separator:" · ") }
    var body:some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ClubPage {
                    Color.clear.frame(height:1).id("builder-top")
                    hero
                    ClubHeading(eyebrow:ClubBuilder.isPizza(item) ? "YOUR PIZZA. YOUR WAY." : "MAKE IT YOURS",title:item["name"].text,subtitle:item["description"].text)
                    stepStrip
                    if current.id == "size" { sizes }
                    else if current.id == "finish" { review }
                    else { ForEach(current.groups) { group in options(group) } }
                    if store.pending != nil { Label("Review your pending request in Account before changing the bag.",systemImage:"exclamationmark.circle").font(.subheadline).foregroundStyle(.orange) }
                    Text("Only choices offered by the restaurant are shown. Ingredient pictures are illustrations, not allergy or recipe guarantees.").font(.caption).foregroundStyle(.secondary)
                }.onChange(of:step) { _,_ in withAnimation(reduced ? nil : .easeInOut(duration:0.22)) { proxy.scrollTo("builder-top",anchor:.top) } }
            }.navigationTitle(existing == nil ? "Make it yours" : "Edit your favorite").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.topBarTrailing) { ClubSheetClose() } }
                .safeAreaInset(edge:.bottom,spacing:0) { footer }
                .overlay { if added { ClubBagCelebration(name:item["name"].text).transition(.opacity) } }
                .sheet(item:$focus) { focused in optionDetails(focused) }
                .task {
                    guard !initialized else { return }; initialized=true
                    size=existing?["size_label"].text ?? ClubMenuRules.sizes(item).first ?? "Regular"
                    quantity=existing?["quantity"].int ?? 1; notes=existing?["notes"].text ?? ""
                    selections=existing.map { ClubBuilder.restore(item,line:$0) } ?? ClubMenuRules.defaults(item)
                }
                .task(id:String(initialized)+"|"+signature) { await quote() }
        }
    }
    private var hero:some View {
        Group {
            if ClubBuilder.isPizza(item) {
                VStack(spacing:8) {
                    ClubPizzaArt(layers:ClubBuilder.layers(item,selections:selections),sauce:baseNames,thin:baseNames.localizedCaseInsensitiveContains("thin"))
                        .frame(maxWidth:270).scaleEffect(size.lowercased().contains("mini") ? 0.83 : size.lowercased().contains("small") ? 0.92 : 1)
                        .animation(reduced ? nil : .spring(response:0.4,dampingFraction:0.75),value:size)
                    HStack { ClubPill(title:size); Text("Selected additions · illustrated").font(.caption).foregroundStyle(.secondary) }
                }.frame(maxWidth:.infinity).padding(.vertical,8).background(ClubStyle.surface,in:RoundedRectangle(cornerRadius:28))
            } else { ClubPhoto(path:item["image_url"].text,height:205) }
        }
    }
    private var stepStrip:some View {
        ScrollView(.horizontal) {
            HStack(spacing:10) { ForEach(Array(steps.enumerated()),id:\.element.id) { index,entry in
                Button { ClubStyle.touch(); step=index } label: {
                    HStack(spacing:8) { Text(String(index+1)).font(.caption.bold()).frame(width:24,height:24).background(step == index ? Color.white.opacity(0.18) : ClubStyle.accent.opacity(0.1),in:Circle());Text(entry.title).font(.subheadline.weight(.semibold)) }
                        .padding(12).foregroundStyle(step == index ? Color.white : ClubStyle.accent).background(step == index ? ClubStyle.green : ClubStyle.surface,in:Capsule())
                }.buttonStyle(ClubPressStyle()).accessibilityAddTraits(step == index ? [.isSelected] : [])
            } }
        }.scrollIndicators(.hidden)
    }
    private var sizes:some View {
        ClubPanel {
            ClubSectionTitle(title:"How hungry are we?",detail:"Choose one")
            ForEach(ClubMenuRules.sizes(item),id:\.self) { label in
                Button { ClubStyle.touch();size=label } label: {
                    HStack(spacing:14) { Image(systemName:"circle.dotted").font(.system(size:label.lowercased().contains("mini") ? 25 : 34)).frame(width:42);VStack(alignment:.leading,spacing:4) { Text(label).font(.headline);Text("Base price").font(.caption).foregroundStyle(.secondary) };Spacer();Text(ClubPolicy.money(item["size_prices"][label].number)).font(.headline);Image(systemName:size == label ? "checkmark.circle.fill" : "circle") }
                        .padding(16).foregroundStyle(size == label ? ClubStyle.accent : .primary).background(size == label ? ClubStyle.accent.opacity(0.10) : Color.secondary.opacity(0.04),in:RoundedRectangle(cornerRadius:18))
                }.buttonStyle(ClubPressStyle()).accessibilityAddTraits(size == label ? [.isSelected] : [])
            }
        }
    }
    private func options(_ group:J)->some View {
        ClubPanel {
            HStack { Text(group.first("customer_label","name")).font(.title2.bold());Spacer();ClubPill(title:group["required"].truth ? "Required" : "Optional") }
            Text(group["selection_type"].text == "single" ? "Choose one" : "\(selections[group.id]?.count ?? 0) selected · up to \(ClubBuilder.maximum(group))").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns:[GridItem(.adaptive(minimum:130),spacing:12)],spacing:12) {
                ForEach(ClubBuilder.options(group)) { option in ingredientTile(group,option) }
            }
        }.disabled(added || store.busy || store.pending != nil)
    }
    private func ingredientTile(_ group:J,_ option:J)->some View {
        let choice=selections[group.id]?.first { $0["option_id"].text == option.id }
        let selected=choice != nil
        return VStack(spacing:8) {
            Button {
                ClubStyle.touch(); let next=ClubBuilder.toggle(group,option:option,current:selections[group.id] ?? [])
                withAnimation(reduced ? nil : .spring(response:0.3,dampingFraction:0.8)) { selections[group.id]=next }
            } label: {
                VStack(spacing:10) {
                    ZStack(alignment:.topTrailing) {
                        if ClubPolicy.media(option["image_url"].text) != nil { ClubPhoto(path:option["image_url"].text,height:58) }
                        else if ClubBuilder.toppingGroup(group) { ClubIngredientArt(kind:.identify(option["name"].text)).frame(height:58) }
                        else { Image(systemName:group["name"].text.localizedCaseInsensitiveContains("sauce") ? "drop.fill" : "circle.dotted").font(.largeTitle).foregroundStyle(ClubStyle.accent).frame(maxWidth:.infinity).frame(height:58) }
                        Image(systemName:selected ? "checkmark.circle.fill" : "plus.circle").foregroundStyle(selected ? ClubStyle.accent : .secondary)
                    }
                    Text(option["name"].text).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center).frame(maxWidth:.infinity)
                    Text(option["price"].number > 0 ? "Listed +"+ClubPolicy.money(option["price"].number) : "Listed at no extra charge").font(.caption).foregroundStyle(.secondary)
                }.padding(14).frame(maxWidth:.infinity,minHeight:140).background(selected ? ClubStyle.accent.opacity(0.10) : Color.secondary.opacity(0.04),in:RoundedRectangle(cornerRadius:20))
            }.buttonStyle(ClubPressStyle()).accessibilityAddTraits(selected ? [.isSelected] : [])
                .disabled((!selected && focusedGroupIsFull(group)) || (selected && option["removable"] == .bool(false)))
            if let choice {
                Button { focus=ClubOptionFocus(group:group,option:option) } label: { HStack(spacing:4) { Text(portionTitle(choice["portion"].text));Image(systemName:"slider.horizontal.3") }.font(.caption.weight(.semibold)).frame(maxWidth:.infinity,minHeight:44) }.accessibilityLabel("Edit \(option["name"].text) portion and amount")
            }
        }
    }
    private var review:some View {
        VStack(spacing:18) {
            ClubPanel {
                ClubSectionTitle(title:ClubBuilder.isPizza(item) ? "Looks like your kind of pizza." : "Made your way.")
                if existing != nil { Text("Review these choices against the current menu before saving.").font(.caption).foregroundStyle(.secondary) }
                Text(size+" · "+item["name"].text).font(.headline)
                ForEach(Array(ClubMenuRules.displayOptions(item,selections:selections).enumerated()),id:\.offset) { _,title in Label(title,systemImage:"checkmark").font(.subheadline) }
                if let validation { Label(validation,systemImage:"exclamationmark.circle").font(.subheadline).foregroundStyle(.orange) }
                Stepper("Quantity: \(quantity)",value:$quantity,in:1...20)
            }
            ClubPanel { Text("Finishing touches").font(.title3.bold());TextField("Special instructions (optional)",text:$notes,axis:.vertical).lineLimit(3...5);Text("For allergies, please call the restaurant before ordering.").font(.caption).foregroundStyle(.secondary) }
        }.disabled(added || store.busy || store.pending != nil)
    }
    private var footer:some View {
        VStack(spacing:10) {
            HStack { VStack(alignment:.leading,spacing:3) { Text(pricing.isNull ? "Final price at checkout" : ClubPolicy.money(pricing["item_subtotal"].number)).font(.headline);Text(quoting ? "Checking restaurant pricing…" : quoteError ?? "Food quote · tax and tip shown in your bag").font(.caption).foregroundStyle(.secondary) };Spacer();Text("\(quantity) item\(quantity == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary) }
            if added { ClubAction(title:"Continue to the menu",symbol:"checkmark") { dismiss() } }
            else { ClubAction(title:current.id == "finish" ? (existing == nil ? "Add to bag" : "Save changes") : "Continue to \(steps[min(step+1,steps.count-1)].title.lowercased())",symbol:current.id == "finish" ? "bag.badge.plus" : "arrow.right") {
                if current.id == "finish" { save() } else { step=min(step+1,steps.count-1) }
            }.disabled(store.busy || store.pending != nil || (current.id == "finish" && validation != nil)) }
        }.padding(18).background(.regularMaterial)
    }
    private func optionDetails(_ focused:ClubOptionFocus)->some View {
        NavigationStack {
            Form {
                Section { ClubIngredientArt(kind:.identify(focused.option["name"].text)).frame(height:72);Text(focused.option["name"].text).font(.title2.bold()) }
                let portions=ClubBuilder.portions(focused.group,focused.option)
                if portions.count>1 { Section("Where on your pizza?") { Picker("Placement",selection:binding(focused,key:"portion",fallback:portions.first ?? "whole")) { ForEach(portions,id:\.self) { Text(portionTitle($0)).tag($0) } }.pickerStyle(.segmented) } }
                let styles=ClubBuilder.styles(focused.group,focused.option)
                if styles.count>1 { Section("How much?") { Picker("Style",selection:binding(focused,key:"style",fallback:"regular")) { ForEach(styles,id:\.self) { Text($0 == "side" ? "On the side" : $0.capitalized).tag($0) } } } }
                if focused.option["max_quantity"].int>1 { Section("Amount") { Picker("Amount",selection:binding(focused,key:"quantity",fallback:"1")) { ForEach(1...min(10,focused.option["max_quantity"].int),id:\.self) { Text(String($0)).tag(String($0)) } } } }
                Section { Text("Your restaurant quote updates with these choices. Free selections and half-topping pricing are calculated by HOP.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Make it yours").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement:.topBarTrailing) { Button("Done") { focus=nil } } }
        }.presentationDetents([.medium,.large]).presentationDragIndicator(.visible)
    }
    private func binding(_ focused:ClubOptionFocus,key:String,fallback:String)->Binding<String> {
        Binding(get:{ selections[focused.group.id]?.first { $0["option_id"].text == focused.option.id }?[key].text ?? fallback },set:{ value in
            var next=selections[focused.group.id] ?? []
            if let index=next.firstIndex(where:{ $0["option_id"].text == focused.option.id }) { next[index][key]=key == "quantity" ? .n(Int(value) ?? 1) : .s(value) }
            selections[focused.group.id]=next
        })
    }
    private func portionTitle(_ value:String)->String { value == "left" ? "Left half" : value == "right" ? "Right half" : "Whole" }
    private func focusedGroupIsFull(_ group:J)->Bool { group["selection_type"].text != "single" && (selections[group.id]?.count ?? 0) >= ClubBuilder.maximum(group) }
    private func save() {
        guard validation == nil,!added,!store.busy,store.pending == nil else { return }
        if let existing { guard let index=store.cart.firstIndex(where:{$0.id == existing.id}) else { store.error="This item is no longer in your bag. Please add it again.";return };store.cart[index]=line.set(["id":.s(existing.id)]) }
        else { store.cart.append(line) }
        withAnimation(reduced ? nil : .easeInOut(duration:0.2)) { added=true }
    }
    private func quote() async {
        let ticket=signature; pricing = .null;quoteError=nil
        guard initialized,validation == nil,store.ordering,store.pending == nil else { return }
        quoting=true;defer { if signature == ticket { quoting=false } }
        do { try await Task.sleep(for:.milliseconds(350));try Task.checkCancellation();let result=try await store.quoteLine(line);if !Task.isCancelled,signature == ticket { pricing=result } }
        catch is CancellationError {} catch { if !Task.isCancelled,signature == ticket { quoteError="Check your final quote in the bag." } }
    }
}
