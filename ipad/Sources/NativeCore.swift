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

enum HOPDay {
    static var calendar:Calendar { var c = Calendar(identifier:.gregorian); c.timeZone = TimeZone(secondsFromGMT:0)!; return c }
    static func parse(_ value:String) -> Date? { let f = DateFormatter(); f.calendar = calendar; f.locale = Locale(identifier:"en_US_POSIX"); f.timeZone = calendar.timeZone; f.dateFormat = "yyyy-MM-dd"; f.isLenient = false; return f.date(from:String(value.prefix(10))) }
    static func iso(_ date:Date) -> String { let f = DateFormatter(); f.calendar = calendar; f.locale = Locale(identifier:"en_US_POSIX"); f.timeZone = calendar.timeZone; f.dateFormat = "yyyy-MM-dd"; return f.string(from:date) }
    static var today:String { let f = DateFormatter(); f.locale = Locale(identifier:"en_US_POSIX"); f.timeZone = TimeZone(identifier:"America/New_York"); f.dateFormat="yyyy-MM-dd"; return f.string(from:Date()) }
    static func add(_ day:String,_ offset:Int) -> String { guard let d=parse(day),let next=calendar.date(byAdding:.day,value:offset,to:d) else { return day }; return iso(next) }
    static func weekday(_ value:String) -> Int { guard let d=parse(value) else { return -1 }; return calendar.component(.weekday,from:d)-1 }
    static func week(_ day:String) -> String { add(day,-((weekday(day)-2+7)%7)) }
    static func label(_ day:String,_ format:String = "EEE, MMM d") -> String { guard let d=parse(day) else { return day }; let f=DateFormatter(); f.calendar=calendar; f.timeZone=calendar.timeZone; f.locale=Locale(identifier:"en_US"); f.dateFormat=format; return f.string(from:d) }
    static func days(_ week:String) -> [String] { (0..<6).map { add(week,$0) } }
}
enum HOPMoney {
    static func cents(_ dollars:String) -> Int { guard let value=Decimal(string:dollars,locale:Locale(identifier:"en_US_POSIX")),abs(NSDecimalNumber(decimal:value).doubleValue)<100_000_000 else {return 0}; return NSDecimalNumber(decimal:value).multiplying(by:100).rounding(accordingToBehavior:rounder).intValue }
    static var rounder:NSDecimalNumberHandler { NSDecimalNumberHandler(roundingMode:.plain,scale:0,raiseOnExactness:false,raiseOnOverflow:false,raiseOnUnderflow:false,raiseOnDivideByZero:false) }
    static func show(_ cents:Int) -> String { String(format:"$%.2f",Double(cents)/100) }
    static func dollars(_ cents:Int) -> String { String(format:"%.2f",Double(cents)/100) }
    static func round(_ value:Double) -> Int { Int(value.rounded(.toNearestOrAwayFromZero)) }
    // Existing API rows store the applied total discount, not only its fixed component.
    static func editableInvoice(_ saved:J)->J {
        let percent=round(Double(saved["subtotal_cents"].int)*saved["discount_basis_points"].number/10000)
        return saved.set(["discount_cents":.n(max(0,saved["discount_cents"].int-percent))])
    }
    static func totals(_ document:J) -> J {
        let subtotal=document["items"].array.reduce(0) { $0 + round($1["quantity"].number * $1["unit_price_cents"].number) }
        let discount=min(subtotal,max(0,document["discount_cents"].int)+round(Double(subtotal)*document["discount_basis_points"].number/10000))
        let taxable=max(0,subtotal-discount), tax=round(Double(taxable)*document["tax_rate_basis_points"].number/10000)
        let total=taxable+tax+document["gratuity_cents"].int+document["delivery_fee_cents"].int+document["other_fee_cents"].int
        let paid=document["status"].text == "paid" ? total : min(total,max(0,document["amount_paid_cents"].int))
        return document.set(["subtotal_cents":.n(subtotal),"applied_discount_cents":.n(discount),"tax_cents":.n(tax),"total_cents":.n(total),"card_total_cents":.n(total+round(Double(total)*document["card_fee_basis_points"].number/10000)),"amount_paid_cents":.n(paid),"balance_due_cents":.n(max(0,total-paid))])
    }
}

enum BoardRules {
    static func roleMatch(_ employee:J,_ row:J) -> Bool {
        func token(_ value:String)->String {value.lowercased().filter {!$0.isWhitespace && $0 != "_" && $0 != "-"}}
        let roles=([employee["role"].text]+employee["secondary_roles"].array.map(\.text)).map(token)
        let wanted=token(row["role_group"].text+row["label"].text)
        if roles.contains("manager") { return true }
        if wanted.contains("host") {return roles.contains {$0.contains("host")}}
        if wanted.contains("floor") || wanted.contains("fh") {return roles.contains {$0.contains("floor") || $0 == "fh"}}
        if ["wait","main","am","pm"].contains(where:wanted.contains) {return roles.contains {$0.contains("wait") || $0.contains("server")}}
        return true
    }
    static func entries(_ schedule:J,row:J,day:String) -> [J] { schedule["entries"].array.filter { $0["row_id"].text == row.id && $0["day_of_week"].int == HOPDay.weekday(day) } }
    static func closed(_ entries:[J]) -> Bool { !entries.contains {$0["notes"].text.contains("HOP_SLOT_ACTIVE")} && entries.contains { $0["notes"].text.contains("HOP_SLOT_INACTIVE") } }
    static func cellClosed(_ entries:[J],row:J,day:String)->Bool {
        if entries.contains(where:{!$0["employee_id"].text.isEmpty || $0["notes"].text.contains("HOP_SLOT_ACTIVE")}) {return false}
        if closed(entries) {return true}
        let key=row.first("row_key","key"),weekday=HOPDay.weekday(day)
        if ["main_am1","main_am2","host_am1"].contains(key) {return weekday == 6}
        if ["main_am3","main_am4","main_fh2","main_fh3","main_fh4"].contains(key) {return weekday != 0}
        return false
    }
    static func activeNotes(_ entry:J)->String {
        let note=entry["notes"].text.replacingOccurrences(of:"HOP_SLOT_INACTIVE",with:"").replacingOccurrences(of:"HOP_SLOT_ACTIVE",with:"").trimmingCharacters(in:.whitespacesAndNewlines)
        return note.isEmpty ? "HOP_SLOT_ACTIVE" : note+"\nHOP_SLOT_ACTIVE"
    }
    static func defaults(_ row:J) -> (String,String) {
        if !row["default_start_time"].text.isEmpty { return (String(row["default_start_time"].text.prefix(5)),String(row["default_end_time"].text.prefix(5))) }
        let map:[String:(String,String)] = ["AM1":("10:00","15:00"),"AM2":("11:00","16:00"),"AM3":("11:30","16:30"),"AM4":("12:00","17:00"),"PM1":("15:00","19:30"),"PM2":("16:00","20:30"),"PM3":("17:00","21:00"),"FH1":("16:00","20:30"),"FH2":("17:00","21:00"),"FH3":("17:30","21:30"),"FH4":("18:00","22:00"),"Host AM1":("11:00","16:00"),"Host PM1":("16:00","21:00"),"Host PM2":("17:00","21:00")]
        return map[row["label"].text] ?? ("10:00","15:00")
    }
    static func overlaps(_ candidate:J,_ entries:[J]) -> Bool {
        guard !candidate["employee_id"].text.isEmpty else { return false }
        return entries.contains { $0.id != candidate.id && $0["employee_id"] == candidate["employee_id"] && $0["day_of_week"] == candidate["day_of_week"] && $0["start_time"].text.prefix(5) < candidate["end_time"].text.prefix(5) && candidate["start_time"].text.prefix(5) < $0["end_time"].text.prefix(5) }
    }
    static func off(_ employee:J,day:String,row:J,availability:[J]) -> Bool {
        availabilityState(employee,day:day,row:row,availability:availability) == "off"
    }
    static func shiftKey(_ row:J,start:String="")->String {
        let text=(row["label"].text+" "+row["role_group"].text).uppercased()
        if text.contains("AM") {return "AM"}
        if ["PM","FH","FLOOR"].contains(where:text.contains) {return "PM"}
        return (Int(start.prefix(2)) ?? 0)<15 ? "AM" : "PM"
    }
    static func availabilityState(_ employee:J,day:String,row:J,availability:[J],start:String="")->String {
        let shift=shiftKey(row,start:start),dayName=HOPDay.label(day,"EEE").lowercased()
        let records=availability.filter {slot in
            let week=String(slot["week_start"].text.prefix(10))
            return slot["employee_id"].text == employee.id && (week.isEmpty || week == HOPDay.week(day)) && (slot["day"].text.lowercased().prefix(3) == dayName.prefix(3) || slot["day"].text == String(HOPDay.weekday(day))) && slot["shift_key"].text.uppercased() == shift
        }
        if records.contains(where:{$0["status"].text.lowercased() == "off"}) {return "off"}
        return records.contains(where:{$0["status"].text.lowercased() == "available"}) ? "available" : "default"
    }
    static func taskMatches(_ task:J,row:J,day:String) -> Bool {
        let role=row["role_group"].text == "host" ? "host" : row["role_group"].text == "floor" ? "support" : "main"
        let shift=row["label"].text.contains("AM") ? "AM" : "PM"
        let number=Int(row["label"].text.filter(\.isNumber)) ?? 1
        return task["status"].text != "done" && ["","all",role].contains(task["role_group"].text) && ["","all",shift].contains(task["shift"].text) && (task["day_of_week"].isNull || task["day_of_week"].int == HOPDay.weekday(day)) && (task["shift_number"].isNull || task["shift_number"].int == number)
    }
}

enum WallBoardLayout {
    // Letter landscape: compact header, optional party ribbon, grid, footer.
    static let gridTop:Double=158
    static let gridBottom:Double=574
    static func rowHeights(assignmentCounts:[Int])->[Double] {
        let minimum=assignmentCounts.map {Double(max(1,$0)*29+5)}
        let spare=max(0,gridBottom-gridTop-minimum.reduce(0,+))
        return minimum.map {$0+(minimum.isEmpty ? 0 : spare/Double(minimum.count))}
    }
    static func time(_ raw:String)->String {
        let parts=raw.split(separator:":");guard parts.count>=2,let hour=Int(parts[0]),let minute=Int(parts[1]) else{return raw}
        return "\(hour%12 == 0 ? 12 : hour%12):\(String(format:"%02d",minute)) \(hour<12 ? "AM" : "PM")"
    }
}

struct LaborLine:Identifiable {
    var id:String;var employeeID:String;var weekday:Int;var role:String;var slot:String
    var hours:Double;var rate:Int;var missingRate:Bool
    var pay:Int {HOPMoney.round(hours*Double(rate))}
    static func make(schedule:J,employees:[J])->[LaborLine] {
        schedule["entries"].array.enumerated().compactMap {index,entry in
            guard !entry["employee_id"].text.isEmpty else {return nil}
            let person=employees.first {$0.id == entry["employee_id"].text} ?? .null
            let row=schedule["rows"].array.first {$0.id == entry["row_id"].text} ?? .null
            let role=row["role_group"].text.isEmpty ? person["role"].text : row["role_group"].text
            let rate=person["role_pay_rates"][role].isNull ? person["pay_rate_cents"] : person["role_pay_rates"][role]
            func minutes(_ s:String)->Double {let p=s.split(separator:":");return p.count>=2 ? (Double(p[0]) ?? 0)*60+(Double(p[1]) ?? 0) : 0}
            return LaborLine(id:entry.id.isEmpty ? String(index) : entry.id,employeeID:entry["employee_id"].text,weekday:entry["day_of_week"].int,role:role,slot:row["label"].text,hours:max(0,minutes(entry["end_time"].text)-minutes(entry["start_time"].text))/60,rate:rate.int,missingRate:rate.isNull)
        }
    }
}
