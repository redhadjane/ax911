import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

enum ClubPolicy {
    static let origin="https://www.houseofpizzagaffney.com"
    static let publicReads:Set<String>=["/api/hopclub/menu","/api/hopclub/v2/config","/api/website-content"]
    static func url(_ path:String,method:String="GET")->URL? {
        guard !path.contains("%"),!path.contains("\\"),!path.contains("?"),!path.contains("#"),!path.contains("..") else{return nil}
        let reads=publicReads.union(["/api/hopclub/v2/me","/api/hopclub/v2/orders","/api/hopclub/v2/member-qr"])
        let posts:Set<String>=["/api/hopclub/v2/login","/api/hopclub/v2/orders/quote","/api/hopclub/v2/orders","/api/hopclub/v2/redemptions"]
        let redemption=path.range(of:"^/api/hopclub/v2/redemptions/[A-Fa-f0-9-]{36}(/qr)?$",options:.regularExpression) != nil
        guard (method == "GET" && (reads.contains(path) || redemption)) || (method == "POST" && posts.contains(path)) else{return nil}
        return URL(string:origin+path)
    }
    static func media(_ path:String)->URL? {
        guard !path.isEmpty,let url=URL(string:path,relativeTo:URL(string:origin))?.absoluteURL,url.scheme == "https",url.host == "www.houseofpizzagaffney.com",url.user == nil,url.password == nil,url.port == nil || url.port == 443,!url.path.hasPrefix("/api/") else{return nil};return url
    }
    static func money(_ value:Double)->String {String(format:"$%.2f",value)}
    static func date(_ raw:String)->String {
        let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        let plain=ISO8601DateFormatter()
        guard let date=f.date(from:raw) ?? plain.date(from:raw) else{return raw}
        let out=DateFormatter();out.timeZone=TimeZone(identifier:"America/New_York");out.dateStyle = .medium;out.timeStyle = .short;return out.string(from:date)
    }
}
enum ClubMenuRules {
    static func groups(_ item:J)->[J] {item["customization"]["modifier_groups"].array.filter {$0["is_active"] != .bool(false) && $0["online_visible"] != .bool(false) && !$0["archived"].truth}}
    static func sizes(_ item:J)->[String] {item["size_prices"].object.keys.sorted {item["size_prices"][$0].number<item["size_prices"][$1].number}}
    static func defaults(_ item:J)->[String:[J]] {
        Dictionary(uniqueKeysWithValues:groups(item).map {group in (group.id,group["options"].array.filter {$0["is_active"] != .bool(false) && $0["default_selected"].truth}.map {option in .object(["option_id":.s(option.id),"portion":.s("whole"),"style":.s("regular"),"quantity":.n(1)])})})
    }
    static func validation(_ item:J,size:String,selections:[String:[J]])->String? {
        if !sizes(item).isEmpty && !sizes(item).contains(size) {return "Choose a size."}
        for group in groups(item) {
            let count=selections[group.id]?.count ?? 0,minimum=max(group["required"].truth ? 1 : 0,group["min_selections"].int)
            let maximum=max(minimum,group["max_selections"].isNull ? (group["selection_type"].text == "single" ? 1 : 99) : group["max_selections"].int)
            if count<minimum {return "Choose at least \(minimum) for \(group["name"].text)."}
            if count>maximum {return "Choose no more than \(maximum) for \(group["name"].text)."}
        }
        return nil
    }
    static func line(_ item:J,size:String,quantity:Int,selections:[String:[J]],notes:String)->J {
        .object(["id":.s(UUID().uuidString),"name":item["name"],"image_url":item["image_url"],"display_options":.array(displayOptions(item,selections:selections).map(J.s)),"menu_item_id":.s(item.id),"size_label":.s(size),"quantity":.n(quantity),"modifier_selections":.array(groups(item).map {group in .object(["group_id":.s(group.id),"options":.array(selections[group.id] ?? [])])}),"notes":.s(String(notes.prefix(800)))])
    }
    // Human-readable local review only; never sent as authoritative pricing or modifiers.
    static func displayOptions(_ item:J,selections:[String:[J]])->[String] {
        groups(item).flatMap {group in (selections[group.id] ?? []).compactMap {selection -> String? in
            guard let option=group["options"].array.first(where:{$0.id == selection["option_id"].text}) else{return nil}
            var labels=[option["name"].text]
            if selection["portion"].text == "left" {labels.append("left half")}
            if selection["portion"].text == "right" {labels.append("right half")}
            if !selection["style"].text.isEmpty && selection["style"].text != "regular" {labels.append(selection["style"].text == "side" ? "on the side" : selection["style"].text)}
            if selection["quantity"].int>1 {labels.append("×\(selection["quantity"].int)")}
            return labels.joined(separator:" · ")
        }}
    }
    static func requestItems(_ cart:[J])->[J] {cart.map {.object(["menu_item_id":$0["menu_item_id"],"size_label":$0["size_label"],"quantity":$0["quantity"],"modifier_selections":$0["modifier_selections"],"notes":$0["notes"]])}}
}

// Draw only the QR module strokes emitted by the existing server's qrcode package.
// No scripts, external entities, links or general SVG documents are evaluated.
struct ClubQR {
    struct Run:Equatable {var x:Double;var y:Double;var width:Double}
    var dimension:Double;var runs:[Run]
    static func parse(_ data:Data)->ClubQR? {
        guard data.count<250_000,let source=String(data:data,encoding:.utf8),!source.localizedCaseInsensitiveContains("<!DOCTYPE"),!source.localizedCaseInsensitiveContains("<!ENTITY") else{return nil}
        let reader=QRReader(),parser=XMLParser(data:data);parser.shouldResolveExternalEntities=false;parser.delegate=reader
        guard parser.parse(),!reader.invalid,reader.size>0,reader.size<=200,!reader.stroke.isEmpty else{return nil}
        let pattern="[Mmh]|-?[0-9]+(?:\\.[0-9]+)?"
        guard let regex=try? NSRegularExpression(pattern:pattern) else{return nil}
        let ns=reader.stroke as NSString
        let matches=regex.matches(in:reader.stroke,range:NSRange(location:0,length:ns.length))
        let tokens=matches.map {ns.substring(with:$0.range)}
        let remainder=regex.stringByReplacingMatches(in:reader.stroke,range:NSRange(location:0,length:ns.length),withTemplate:"").trimmingCharacters(in:.whitespacesAndNewlines)
        guard remainder.isEmpty,tokens.count<60000 else{return nil}
        var x=0.0,y=0.0,index=0,runs:[Run]=[]
        while index<tokens.count {
            let command=tokens[index];index += 1
            guard index<tokens.count,let a=Double(tokens[index]) else{return nil};index += 1
            if command == "M" || command == "m" {
                guard index<tokens.count,let b=Double(tokens[index]) else{return nil};index += 1
                x=command == "M" ? a : x+a;y=command == "M" ? b : y+b
            } else if command == "h" {
                guard a>0,x>=0,y>=0.5,x+a<=reader.size,y+0.5<=reader.size else{return nil}
                runs.append(Run(x:x,y:y-0.5,width:a));x += a
            } else{return nil}
        }
        return runs.isEmpty ? nil : ClubQR(dimension:reader.size,runs:runs)
    }
    private final class QRReader:NSObject,XMLParserDelegate {
        var size=0.0;var stroke="";var invalid=false
        func parser(_ parser:XMLParser,didStartElement name:String,namespaceURI:String?,qualifiedName:String?,attributes:[String:String]) {
            if name == "svg" {let parts=(attributes["viewBox"] ?? "").split(separator:" ").compactMap {Double($0)};if parts.count == 4 && parts[0] == 0 && parts[1] == 0 && parts[2] == parts[3] {size=parts[2]}else{invalid=true}}
            else if name == "path" {if attributes["stroke"] != nil {stroke += attributes["d"] ?? ""}}
            else {invalid=true}
        }
    }
}
