import Foundation

enum J: Codable, Equatable, Sendable, Identifiable {
    case object([String:J]), array([J]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([J].self) { self = .array(a) }
        else { self = .object(try c.decode([String:J].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .object(let x): try c.encode(x); case .array(let x): try c.encode(x); case .string(let x): try c.encode(x); case .number(let x): try c.encode(x); case .bool(let x): try c.encode(x); case .null: try c.encodeNil() }
    }
    subscript(_ key:String) -> J { get { if case .object(let o) = self { return o[key] ?? .null }; return .null } set { var o = object; o[key] = newValue; self = .object(o) } }
    var object:[String:J] { if case .object(let o) = self { return o }; return [:] }
    var array:[J] { if case .array(let a) = self { return a }; return [] }
    var text:String { switch self { case .string(let s): return s; case .number(let n): return n == n.rounded() ? String(format:"%.0f",n) : String(n); case .bool(let b): return b ? "true" : "false"; default:return "" } }
    var number:Double { if case .number(let n) = self { return n }; return Double(text) ?? 0 }
    var int:Int { Int(number) }
    var isNull:Bool { self == .null }
    var truth:Bool { self == .bool(true) || text == "true" || text == "1" }
    var id:String { first("id","row_key","code","name","title") }
    func first(_ keys:String...) -> String { keys.map { self[$0].text }.first { !$0.isEmpty } ?? "" }
    func list(_ keys:String...) -> [J] { if case .array = self { return array }; for k in keys { if case .array = self[k] { return self[k].array } }; return [] }
    func set(_ values:[String:J]) -> J { .object(object.merging(values) { _,n in n }) }
    static func s(_ s:String) -> J { .string(s) }
    static func n(_ n:Int) -> J { .number(Double(n)) }
    var pretty:String { guard let data = try? JSONEncoder().encode(self) else { return "" }; return String(data:data,encoding:.utf8) ?? "" }
    var humanText:String {switch self {case .array(let values):return values.map(\.humanText).joined(separator:"\n");case .object(let values):return values.keys.sorted().map {$0.replacingOccurrences(of:"_",with:" ").capitalized+": "+(values[$0]?.humanText ?? "")}.joined(separator:"\n");default:return text}}
}
