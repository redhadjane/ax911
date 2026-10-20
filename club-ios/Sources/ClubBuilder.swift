import Foundation

// Presentation describes the current catalog label, never a legacy option ID.
enum ClubIngredient: String, CaseIterable {
    case pepperoni, salami, ham, bacon, sausage, beef, chicken, steak, shrimp
    case mushroom, olive, greenOlive, pepper, bananaPepper, jalapeno, onion, pineapple, broccoli, cheese, tomato, spinach, generic
    static func identify(_ name: String) -> Self {
        let text = name.lowercased()
        let names: [(String, Self)] = [("pepperoni",.pepperoni),("salami",.salami),("pineapple",.pineapple),("pinnapple",.pineapple),("banana",.bananaPepper),("jalap",.jalapeno),("jalop",.jalapeno),("green olive",.greenOlive),("olive",.olive),("mushroom",.mushroom),("onion",.onion),("broccoli",.broccoli),("spinach",.spinach),("tomato",.tomato),("pepper",.pepper),("cheese",.cheese),("shrimp",.shrimp),("chicken",.chicken),("steak",.steak),("bacon",.bacon),("sausage",.sausage),("beef",.beef),("ham",.ham)]
        return names.first { text.contains($0.0) }?.1 ?? .generic
    }
}
struct ClubBuildStep: Identifiable, Equatable {
    let id: String; let title: String; let groups: [J]
}
struct ClubToppingLayer: Identifiable {
    let id: String; let name: String; let kind: ClubIngredient; let portion: String; let style: String; let quantity: Int
}
enum ClubBuilder {
    static func isPizza(_ item: J) -> Bool { item["name"].text.localizedCaseInsensitiveContains("pizza") && !item["name"].text.localizedCaseInsensitiveContains("dessert") }
    static func toppingGroup(_ group: J) -> Bool { group["allow_half"].truth || group.first("customer_label", "name").localizedCaseInsensitiveContains("topping") }
    static func steps(_ item: J) -> [ClubBuildStep] {
        let groups = ClubMenuRules.groups(item).sorted { $0["sort_order"].number < $1["sort_order"].number }
        var result: [ClubBuildStep] = []
        if !ClubMenuRules.sizes(item).isEmpty { result.append(.init(id:"size", title:"Size", groups:[])) }
        let base = groups.filter { !toppingGroup($0) }, toppings = groups.filter(toppingGroup)
        if !base.isEmpty { result.append(.init(id:"base", title:isPizza(item) ? "Base" : "Choices", groups:base)) }
        if !toppings.isEmpty { result.append(.init(id:"toppings", title:"Toppings", groups:toppings)) }
        result.append(.init(id:"finish", title:"Review", groups:[])); return result
    }
    static func options(_ group: J) -> [J] { group["options"].array.filter { $0["is_active"] != .bool(false) } }
    static func portions(_ group: J, _ option: J) -> [String] {
        var result: [String] = []
        if option["allow_whole"] != .bool(false) { result.append("whole") }
        if group["allow_half"].truth {
            if option["allow_left"] != .bool(false) { result.append("left") }
            if option["allow_right"] != .bool(false) { result.append("right") }
        }
        return result
    }
    static func styles(_ group: J, _ option: J) -> [String] {
        guard group["supports_styles"].truth else { return ["regular"] }
        return ["regular"] + (option["available_as_light"].truth ? ["light"] : []) + (option["available_as_extra"] != .bool(false) ? ["extra"] : []) + (option["available_on_side"].truth ? ["side"] : [])
    }
    static func maximum(_ group: J) -> Int {
        if group["selection_type"].text == "single" { return 1 }
        return max(0, group["max_selections"].isNull ? 99 : group["max_selections"].int)
    }
    static func toggle(_ group: J, option: J, current: [J]) -> [J] {
        if current.contains(where: { $0["option_id"].text == option.id }) {
            if option["removable"] == .bool(false) || (group["selection_type"].text == "single" && group["required"].truth) { return current }
            return current.filter { $0["option_id"].text != option.id }
        }
        guard let portion = portions(group,option).first, options(group).contains(where: { $0.id == option.id }) else { return current }
        var next = group["selection_type"].text == "single" ? [] : current
        guard next.count < maximum(group) else { return current }
        next.append(.object(["option_id":.s(option.id),"portion":.s(portion),"style":.s("regular"),"quantity":.n(1)])); return next
    }
    static func selections(_ line: J) -> [String: [J]] {
        Dictionary(line["modifier_selections"].array.map { ($0["group_id"].text,$0["options"].array) }, uniquingKeysWith: { _, last in last })
    }
    static func restore(_ item:J,line:J)->[String:[J]] {
        let old=selections(line)
        return Dictionary(uniqueKeysWithValues:ClubMenuRules.groups(item).map { group in
            let values=(old[group.id] ?? []).compactMap { choice -> J? in
                guard let option=options(group).first(where:{$0.id == choice["option_id"].text}),let fallback=portions(group,option).first else { return nil }
                let portion=portions(group,option).contains(choice["portion"].text) ? choice["portion"].text : fallback
                let style=styles(group,option).contains(choice["style"].text) ? choice["style"].text : "regular"
                return choice.set(["portion":.s(portion),"style":.s(style),"quantity":.n(max(1,min(max(1,option["max_quantity"].int),choice["quantity"].int)))])
            }
            return (group.id,Array(values.prefix(maximum(group))))
        })
    }
    static func layers(_ item: J, selections: [String: [J]]) -> [ClubToppingLayer] {
        ClubMenuRules.groups(item).filter(toppingGroup).flatMap { group in
            (selections[group.id] ?? []).compactMap { choice in
                guard let option = options(group).first(where: { $0.id == choice["option_id"].text }), choice["style"].text != "side" else { return nil }
                return ClubToppingLayer(id:group.id+"|"+option.id, name:option["name"].text, kind:.identify(option["name"].text), portion:choice["portion"].text, style:choice["style"].text, quantity:max(1,min(10,choice["quantity"].int)))
            }
        }
    }
    static func positions(seed: String, portion: String, count: Int) -> [(Double, Double)] {
        var hash: UInt64 = 14695981039346656037
        for value in seed.utf8 { hash = (hash ^ UInt64(value)) &* 1099511628211 }
        let phase = Double(hash % 1000) / 1000 * Double.pi * 2
        return (0..<max(0,min(80,count))).map { index in
            let radius = 0.72 * sqrt((Double(index)+0.5)/Double(max(1,count)))
            let angle = phase + Double(index) * 2.399963229728653
            var x = radius*cos(angle), y = radius*sin(angle)
            if portion == "left" { x = -abs(x)*0.88-0.08 }
            if portion == "right" { x = abs(x)*0.88+0.08 }
            return (x,y)
        }
    }
}
