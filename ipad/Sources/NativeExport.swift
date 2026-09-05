import SwiftUI
import PDFKit
import UIKit

struct NativeDocument:Identifiable { let id=UUID(); var title:String; var data:Data }
struct NativePDFCanvas:UIViewRepresentable {
    var data:Data
    func makeUIView(context:Context)->PDFView {let view=PDFView();view.autoScales=true;view.displayMode = .singlePageContinuous;view.backgroundColor = .secondarySystemBackground;return view}
    func updateUIView(_ view:PDFView,context:Context) {if view.document?.dataRepresentation() != data {view.document=PDFDocument(data:data);view.autoScales=true}}
}
struct NativeShare:UIViewControllerRepresentable {
    var items:[Any]
    func makeUIViewController(context:Context)->UIActivityViewController {UIActivityViewController(activityItems:items,applicationActivities:nil)}
    func updateUIViewController(_ controller:UIActivityViewController,context:Context) {}
}
struct NativeDocumentPreview:View {
    @Environment(\.dismiss) var dismiss
    var document:NativeDocument
    @State private var shareURL:URL?; @State private var sharing=false; @State private var error:String?
    var body:some View {NavigationStack {NativePDFCanvas(data:document.data).navigationTitle(document.title).navigationBarTitleDisplayMode(.inline).toolbar {
        ToolbarItem(placement:.cancellationAction) {Button("Done"){dismiss()}}
        ToolbarItemGroup(placement:.primaryAction) {Button {do {let safe=document.title.filter {$0.isLetter || $0.isNumber || $0 == " " || $0 == "-"};let url=FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-\(safe).pdf");try document.data.write(to:url,options:.atomic);shareURL=url;sharing=true}catch {self.error=error.localizedDescription}} label:{Label("Share PDF",systemImage:"square.and.arrow.up")};Button {let print=UIPrintInteractionController.shared;let info=UIPrintInfo(dictionary:nil);info.jobName=document.title;info.outputType = .general;print.printInfo=info;print.printingItem=document.data;print.present(animated:true)} label:{Label("AirPrint",systemImage:"printer")}}
    }.sheet(isPresented:$sharing,onDismiss:{if let shareURL {try? FileManager.default.removeItem(at:shareURL)};shareURL=nil}) {if let shareURL {NativeShare(items:[shareURL])}}
    .alert("Export",isPresented:Binding(get:{error != nil},set:{if !$0{error=nil}})) {Button("OK"){error=nil}} message:{Text(error ?? "")}}
}
@MainActor enum NativePDF {
    static let ink=UIColor(red:16/255,green:36/255,blue:31/255,alpha:1)
    static let green=UIColor(red:15/255,green:91/255,blue:76/255,alpha:1)
    static func text(_ value:String,_ rect:CGRect,size:CGFloat=10,bold:Bool=false,color:UIColor=ink) {
        let p=NSMutableParagraphStyle();p.lineBreakMode = .byWordWrapping
        (value as NSString).draw(in:rect,withAttributes:[.font:bold ? UIFont.systemFont(ofSize:size,weight:.semibold) : UIFont.systemFont(ofSize:size),.foregroundColor:color,.paragraphStyle:p])
    }
    static func fill(_ rect:CGRect,_ color:UIColor) {color.setFill();UIBezierPath(roundedRect:rect,cornerRadius:5).fill()}
    static func line(_ y:CGFloat,width:CGFloat=540) {UIColor(white:0.87,alpha:1).setStroke();let p=UIBezierPath();p.move(to:CGPoint(x:36,y:y));p.addLine(to:CGPoint(x:36+width,y:y));p.lineWidth=0.5;p.stroke()}
    static func header(_ title:String,subtitle:String,width:CGFloat) {fill(CGRect(x:30,y:26,width:width-60,height:64),green);if let logo=UIImage(named:"hop-logo") {logo.draw(in:CGRect(x:42,y:37,width:42,height:42))};text("HOUSE OF PIZZA & PASTA",CGRect(x:94,y:37,width:width-136,height:16),size:10,bold:true,color:.white);text(title,CGRect(x:94,y:53,width:width-136,height:27),size:22,bold:true,color:.white);text(subtitle,CGRect(x:36,y:101,width:width-72,height:26),size:10,color:.darkGray)}
    static func invoice(_ input:J)->NativeDocument {
        let d=HOPMoney.totals(input),title=d.first("invoice_number","document_number").isEmpty ? "Invoice preview" : d.first("invoice_number","document_number")
        let paper=CGRect(x:0,y:0,width:612,height:792)
        let data=UIGraphicsPDFRenderer(bounds:paper).pdfData {ctx in
            var y:CGFloat=0,page=0
            func begin() {ctx.beginPage();page += 1;header(d["document_type"].text == "quote" ? "QUOTE" : "INVOICE",subtitle:"\(title) · Customer copy",width:612);y=140
                if page == 1 {text("BILL TO",CGRect(x:36,y:y,width:275,height:16),size:9,bold:true,color:green);text(d["customer_name"].text,CGRect(x:36,y:y+21,width:290,height:27),size:16,bold:true);text([d["contact_name"].text,d["customer_phone"].text,d["customer_email"].text,d["customer_address"].text].filter{!$0.isEmpty}.joined(separator:"\n"),CGRect(x:36,y:y+52,width:290,height:70));let pairs=[("Issued",d["issue_date"].text),("Due",d["due_date"].text),("Event",d["event_date"].text),("Status",d.statusText.capitalized)];for (i,p) in pairs.enumerated(){text(p.0,CGRect(x:360,y:y+CGFloat(i*24),width:80,height:18),color:.darkGray);text(p.1,CGRect(x:445,y:y+CGFloat(i*24),width:130,height:18),bold:true)};y=270}
                fill(CGRect(x:36,y:y,width:540,height:26),green);for (name,x,w) in [("DESCRIPTION",CGFloat(44),CGFloat(320)),("QTY",CGFloat(374),CGFloat(45)),("RATE",CGFloat(425),CGFloat(65)),("AMOUNT",CGFloat(500),CGFloat(70))] {text(name,CGRect(x:x,y:y+8,width:w,height:15),size:8,bold:true,color:.white)};y += 34
            }
            func footer() {line(752);text("Thank you for choosing House of Pizza & Pasta.",CGRect(x:36,y:761,width:460,height:15),size:8);text("\(page)",CGRect(x:554,y:761,width:20,height:15),size:8)}
            begin()
            for item in d["items"].array {let name=item["description"].text;let measured=(name as NSString).boundingRect(with:CGSize(width:318,height:1000),options:.usesLineFragmentOrigin,attributes:[.font:UIFont.systemFont(ofSize:11)],context:nil).height;let h=max(34,measured+18);if y+h>700 {footer();begin()};text(name,CGRect(x:44,y:y+5,width:318,height:h-8),size:11);text(item["quantity"].text,CGRect(x:374,y:y+5,width:45,height:25),size:11);text(HOPMoney.show(item["unit_price_cents"].int),CGRect(x:425,y:y+5,width:68,height:25),size:11);text(HOPMoney.show(HOPMoney.round(item["quantity"].number*item["unit_price_cents"].number)),CGRect(x:500,y:y+5,width:76,height:25),size:11,bold:true);y += h;line(y)}
            var sums:[(String,Int)]=[("Subtotal",d["subtotal_cents"].int)]
            for (key,label) in [("applied_discount_cents","Discount"),("tax_cents","Sales tax"),("delivery_fee_cents","Delivery"),("gratuity_cents","Gratuity"),("other_fee_cents","Other charge")] {if d[key].int != 0 {sums.append((label,key == "applied_discount_cents" ? -d[key].int : d[key].int))}}
            sums.append(("Cash / check total",d["total_cents"].int));if d["card_fee_basis_points"].int>0 {sums.append(("Card total (\(HOPMoney.dollars(d["card_fee_basis_points"].int))% fee)",d["card_total_cents"].int))};if d["amount_paid_cents"].int>0 {sums += [("Paid",d["amount_paid_cents"].int),("Balance due",d["balance_due_cents"].int)]}
            let totalHeight=CGFloat(sums.count*28+25);if y+totalHeight>710 {footer();begin()};y += 18
            text("CUSTOMER NOTE",CGRect(x:36,y:y,width:265,height:18),size:9,bold:true,color:green);text(String(d["customer_note"].text.prefix(600)),CGRect(x:36,y:y+25,width:265,height:min(145,totalHeight)),size:10)
            for (i,sum) in sums.enumerated() {let yy=y+CGFloat(i*28);let strong=sum.0.contains("total") || sum.0 == "Balance due";if strong {fill(CGRect(x:324,y:yy-4,width:252,height:27),green)};text(sum.0,CGRect(x:334,y:yy+3,width:157,height:20),size:10,bold:strong,color:strong ? .white : ink);text(HOPMoney.show(sum.1),CGRect(x:494,y:yy+3,width:80,height:20),size:11,bold:true,color:strong ? .white : ink)};footer()
        };return NativeDocument(title:title,data:data)
    }
    static func schedule(_ schedule:J,week:String,rows:[J],employees:[J],tasks:[J]?=nil)->NativeDocument {
        let title=tasks == nil ? "Weekly schedule" : "Shift task board"
        let data=UIGraphicsPDFRenderer(bounds:CGRect(x:0,y:0,width:792,height:612)).pdfData {ctx in
            let days=HOPDay.days(week);var y:CGFloat=162
            func begin() {ctx.beginPage();header(title,subtitle:"\(HOPDay.label(week)) – \(HOPDay.label(HOPDay.add(week,5))) · \(schedule.statusText.capitalized)",width:792);for (i,day) in days.enumerated(){text(HOPDay.label(day,"EEE · MMM d"),CGRect(x:120+CGFloat(i)*106,y:135,width:104,height:20),size:10,bold:true)};text("HOP · \(title) · Generated \(HOPDay.today)",CGRect(x:36,y:585,width:720,height:15),size:8);y=162}
            begin()
            for row in rows {
                let columns:[[String]]=days.map {day in
                    if let tasks {return tasks.filter {BoardRules.taskMatches($0,row:row,day:day)}.flatMap {wrap("☐ "+$0["title"].text,width:96,size:9)}}
                    return BoardRules.entries(schedule,row:row,day:day).filter {!$0["employee_id"].text.isEmpty}.flatMap {entry -> [String] in
                        let name=employees.first {$0.id == entry["employee_id"].text}?.displayName ?? "Unknown"
                        let double=schedule["entries"].array.filter {$0["employee_id"] == entry["employee_id"] && $0["day_of_week"] == entry["day_of_week"]}.count>1
                        return wrap(name+(double ? " ×2" : ""),width:96,size:9)+["\(String(entry["start_time"].text.prefix(5)))–\(String(entry["end_time"].text.prefix(5)))"]
                    }
                }
                let longest=max(1,columns.map(\.count).max() ?? 1)
                for start in stride(from:0,to:longest,by:30) {
                    let count=min(30,longest-start),height=max(tasks == nil ? CGFloat(37) : 64,CGFloat(count)*12+16)
                    if y+height>572 {begin()}
                    let color=row["role_group"].text == "floor" ? UIColor.systemGray : row["label"].text.contains("AM") ? UIColor.systemBlue : green
                    fill(CGRect(x:36,y:y,width:720,height:height-2),color.withAlphaComponent(0.07));text(row["label"].text+(start>0 ? " (cont.)" : ""),CGRect(x:43,y:y+8,width:73,height:40),size:11,bold:true)
                    for (i,column) in columns.enumerated(){let values=Array(column.dropFirst(start).prefix(30));for (j,value) in (values.isEmpty ? ["—"] : values).enumerated(){text(value,CGRect(x:124+CGFloat(i)*106,y:y+7+CGFloat(j)*12,width:98,height:13),size:9,bold:tasks == nil)}};y += height
                }
            }
        };return NativeDocument(title:title+" "+week,data:data)
    }
    private static func wrap(_ value:String,width:CGFloat,size:CGFloat)->[String] {
        var lines:[String]=[],line="";let font=UIFont.systemFont(ofSize:size,weight:.semibold)
        for word in value.split(separator:" "){let candidate=line.isEmpty ? String(word) : line+" "+word;if (candidate as NSString).size(withAttributes:[.font:font]).width>width && !line.isEmpty {lines.append(line);line=String(word)}else {line=candidate}}
        if !line.isEmpty {lines.append(line)};return lines
    }
    static func parties(_ parties:[J],week:String)->NativeDocument {
        let groups=HOPDay.days(week).map {day in parties.filter {String($0["date"].text.prefix(10)) == day && $0.statusText.lowercased() != "cancelled"}}
        let data=UIGraphicsPDFRenderer(bounds:CGRect(x:0,y:0,width:792,height:612)).pdfData {ctx in
            for start in stride(from:0,to:max(1,groups.map(\.count).max() ?? 1),by:4) {
                ctx.beginPage();header("Party board",subtitle:"\(HOPDay.label(week)) – \(HOPDay.label(HOPDay.add(week,5))) · Reservations & handwritten additions\(start>0 ? " · Continued" : "")",width:792)
                for (i,day) in HOPDay.days(week).enumerated(){let x=36+CGFloat(i)*120;fill(CGRect(x:x,y:140,width:115,height:415),UIColor(white:0.97,alpha:1));text(HOPDay.label(day,"EEEE\nMMM d"),CGRect(x:x+8,y:150,width:100,height:36),size:11,bold:true);var y:CGFloat=200;for p in groups[i].dropFirst(start).prefix(4) {fill(CGRect(x:x+5,y:y,width:105,height:54),UIColor.systemOrange.withAlphaComponent(0.15));text("\(p["time"].text) · \(p["name"].text)\n\(p["count"].text) guests · \(p["area"].text)",CGRect(x:x+10,y:y+6,width:95,height:46),size:9,bold:true);y += 62};text("ADDITIONS / NOTES",CGRect(x:x+8,y:520,width:100,height:16),size:7,color:.gray)};text("Confirm bookings before service. Blank space is reserved for pen-written additions.",CGRect(x:36,y:580,width:720,height:18),size:9)
            }
        };return NativeDocument(title:"Party board "+week,data:data)
    }
    static func record(_ record:J,title:String,fields:[String])->NativeDocument {
        let data=UIGraphicsPDFRenderer(bounds:CGRect(x:0,y:0,width:612,height:792)).pdfData {ctx in ctx.beginPage();header(title,subtitle:record.displayName,width:612);var y:CGFloat=145;for key in fields {let value=record[key].array.isEmpty ? record[key].text : record[key].array.map(\.text).joined(separator:", ");if value.isEmpty {continue};let h=max(44,(value as NSString).boundingRect(with:CGSize(width:360,height:10000),options:.usesLineFragmentOrigin,attributes:[.font:UIFont.systemFont(ofSize:11)],context:nil).height+20);if y+h>730 {ctx.beginPage();header(title,subtitle:"Continued",width:612);y=145};text(key.replacingOccurrences(of:"_",with:" ").capitalized,CGRect(x:36,y:y,width:160,height:h),size:10,bold:true);text(value,CGRect(x:208,y:y,width:368,height:h),size:11);y += h;line(y-8)}};return NativeDocument(title:title,data:data)
    }
}
