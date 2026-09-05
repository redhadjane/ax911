import SwiftUI

struct NativeHome:View {
    @EnvironmentObject var store:NativeStore
    @State private var team="Main"
    var todayEntries:[J] {let schedule=store.schedule("published");return schedule["entries"].array.filter {entry in let row=schedule["rows"].array.first {$0.id == entry["row_id"].text};return !entry["employee_id"].text.isEmpty && entry["day_of_week"].int == HOPDay.weekday(HOPDay.today) && (team == "Host" ? row?["role_group"].text == "host" : row?["role_group"].text != "host")}}
    var parties:[J] {store.items("/api/parties?from=\(store.week)&to=\(HOPDay.add(store.week,20))","parties")}
    var body:some View {NativeScreen(title:"Good \(Calendar.current.component(.hour,from:Date())<12 ? "morning" : "afternoon"), \(store.manager.displayName)",subtitle:HOPDay.label(HOPDay.today,"EEEE, MMMM d, yyyy")) {
        HStack(spacing:16) {metric("On today's team",value:String(todayEntries.count),icon:"person.2");metric("Unread alerts",value:String(store.unread),icon:"bell.badge");metric("Upcoming parties",value:String(parties.filter {String($0["date"].text.prefix(10)) >= HOPDay.today}.count),icon:"party.popper")}
        ViewThatFits(in:.horizontal) {HStack(alignment:.top,spacing:20) {teamPanel.frame(minWidth:340);planning.frame(minWidth:300)};VStack(spacing:20) {teamPanel;planning}}
        HOPPanel(title:"Important today",subtitle:"Requests and recent staff activity") {if store.notifications.isEmpty {Text("No notifications loaded").foregroundStyle(.secondary)};ForEach(Array(store.notifications.prefix(4))){note in Button {store.module = .notifications}label:{HStack {Image(systemName:"bell.badge.fill").foregroundStyle(HOPStyle.red).font(.title2);VStack(alignment:.leading,spacing:6){Text(note["title"].text).font(.headline);Text(note.first("message","body")).foregroundStyle(.secondary).lineLimit(2)};Spacer();Image(systemName:"chevron.right")}.padding(.vertical,8)}.buttonStyle(.plain)};Button("Review requests"){store.module = .inbox}.buttonStyle(.borderedProminent)}
    }.task {if store.week != HOPDay.week(HOPDay.today) {store.week=HOPDay.week(HOPDay.today)}} }
    private func metric(_ title:String,value:String,icon:String)->some View {HOPPanel {Image(systemName:icon).font(.title2).foregroundStyle(HOPStyle.teal);Text(value).font(.system(size:36,weight:.bold,design:.rounded));Text(title).font(.subheadline).foregroundStyle(.secondary)}}
    private var teamPanel:some View {HOPPanel(title:"Today's team") {Picker("Team",selection:$team){Text("Main & floor").tag("Main");Text("Hosts").tag("Host")}.pickerStyle(.segmented);if todayEntries.isEmpty {NativeEmpty(title:"No published shifts",detail:"No \(team.lowercased()) assignments for today in the published week.",icon:"person.2")};ForEach(todayEntries){entry in HStack {PersonMark(name:store.name(entry["employee_id"].text));VStack(alignment:.leading,spacing:6){Text(store.name(entry["employee_id"].text)).font(.headline);Text("\(String(entry["start_time"].text.prefix(5)))–\(String(entry["end_time"].text.prefix(5)))").foregroundStyle(.secondary)};Spacer()}};Button("Open full schedule"){store.module = .schedule}.buttonStyle(.bordered)}}
    private var planning:some View {HOPPanel(title:"Planning ahead",subtitle:"Next three weeks of bookings") {ForEach(0..<3,id:\.self){i in let week=HOPDay.add(store.week,i*7);let count=parties.filter {let date=String($0["date"].text.prefix(10));return date>=week && date<=HOPDay.add(week,5)}.count;Button {store.week=week;store.module = .schedule}label:{HStack {VStack(alignment:.leading,spacing:7){Text("Week of \(HOPDay.label(week,"MMM d"))").font(.headline);Text("\(count) parties").foregroundStyle(.secondary)};Spacer();Image(systemName:"arrow.up.right")}.padding(.vertical,12)}.buttonStyle(.plain);Divider()};Button("Party calendar"){store.module = .parties}.buttonStyle(.bordered)}}
}
struct NativeTasks:View {
    @EnvironmentObject var store:NativeStore
    @State private var board="Main"
    @State private var library=false
    @State private var editing:J?
    @State private var export:NativeDocument?
    var schedule:J {store.schedule("published").isNull ? store.schedule("draft") : store.schedule("published")}
    var rows:[J] {schedule["rows"].array.filter {board == "Host" ? $0["role_group"].text == "host" : board == "Floor" ? $0["role_group"].text == "floor" : $0["role_group"].text == "waitress"}.sorted {$0["sort_order"].int<$1["sort_order"].int}}
    var tasks:[J] {store.items("/api/tasks","tasks")}
    var body:some View {NativeScreen(title:"Shift task board",subtitle:"Assign work to a role and shift. The employee working that shift receives the assignment.") {WeekControl();HStack {Picker("Department",selection:$board){ForEach(["Main","Host","Floor"],id:\.self){Text($0)}}.pickerStyle(.segmented).frame(maxWidth:400);Toggle("Library",isOn:$library).toggleStyle(.button);Spacer();Button("Export board"){export=NativePDF.schedule(schedule,week:store.week,rows:rows,employees:store.employees,tasks:tasks)}.buttonStyle(.bordered).disabled(rows.isEmpty)}
        if library {Button {editing=newTask() }label:{Label("New library task",systemImage:"plus")}.buttonStyle(.borderedProminent);ForEach(tasks){task in Button {editing=task}label:{HOPPanel {HStack {Image(systemName:"checklist").font(.title2);VStack(alignment:.leading,spacing:5){Text(task["title"].text).font(.headline);Text("\(task["role_group"].text.capitalized) · \(task["shift"].text) · Slot \(task["shift_number"].isNull ? "all" : task["shift_number"].text)").foregroundStyle(.secondary)};Spacer();Image(systemName:"pencil")}}.foregroundStyle(.primary)}.buttonStyle(.plain)}}
        else if rows.isEmpty {NativeEmpty(title:"No schedule rows for this week",detail:"Create a schedule first, or open the task library.",icon:"calendar")}
        else {ScrollView(.horizontal){VStack(spacing:5){HStack {Text("Shift").frame(width:90);ForEach(HOPDay.days(store.week),id:\.self){Text(HOPDay.label($0,"EEE d")).frame(width:150)}}.font(.headline).padding(.vertical,12);ForEach(rows){row in HStack {Text(row["label"].text).font(.headline).frame(width:90);ForEach(HOPDay.days(store.week),id:\.self){day in let list=tasks.filter {BoardRules.taskMatches($0,row:row,day:day)};VStack(alignment:.leading,spacing:10){ForEach(list){task in Button {editing=task}label:{Label(task["title"].text,systemImage:"checkmark.square").font(.subheadline)}.buttonStyle(.plain)};Button {var task=newTask();task["role_group"] = .s(row["role_group"].text == "floor" ? "support" : row["role_group"].text == "host" ? "host" : "main");task["shift"] = .s(row["label"].text.contains("AM") ? "AM" : "PM");task["shift_number"] = .n(Int(row["label"].text.filter(\.isNumber)) ?? 1);task["day_of_week"] = .n(HOPDay.weekday(day));editing=task}label:{Label("Assign task",systemImage:"plus.circle")}.font(.caption.bold())}.padding(12).frame(width:150).frame(minHeight:110,alignment:.topLeading).background(HOPStyle.band(row).opacity(0.08),in:RoundedRectangle(cornerRadius:14))}}}}}}
    }.sheet(item:$editing){NativeTaskEditor(original:$0)}.sheet(item:$export){NativeDocumentPreview(document:$0)} }
    func newTask()->J {.object(["id":.s("new"),"area":.s("Side work"),"role_group":.s("all"),"shift":.s("all"),"status":.s("open")])}
}
struct NativeTaskEditor:View {
    @EnvironmentObject var store:NativeStore;@Environment(\.dismiss) var dismiss;var original:J
    @State private var task:J = .null
    @State private var confirm=false
    var body:some View {NavigationStack {Form {Section {RecordFields(record:$task,fields:[.init(key:"title",title:"Task name"),.init(key:"area",title:"Area"),.init(key:"role_group",title:"Role",kind:.choice(["all","main","host","support"])),.init(key:"shift",title:"Shift",kind:.choice(["all","AM","PM"])),.init(key:"notes",title:"Instructions",kind:.paragraph)])};Section("Recurring assignment") {Picker("Day",selection:Binding(get:{task["day_of_week"].isNull ? -1 : task["day_of_week"].int},set:{task["day_of_week"] = $0 == -1 ? .null : .n($0)})){Text("Every day").tag(-1);ForEach([2,3,4,5,6,0],id:\.self){Text(["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"][$0]).tag($0)}};Picker("Slot",selection:Binding(get:{task["shift_number"].isNull ? 0 : task["shift_number"].int},set:{task["shift_number"] = $0 == 0 ? .null : .n($0)})){Text("All slots").tag(0);ForEach(1...4,id:\.self){Text("Slot \($0)").tag($0)}};Text("This changes the recurring task definition, not just one employee's checklist.").font(.footnote).foregroundStyle(.secondary)};if original.id != "new" {Section {Button("Delete library task",role:.destructive){confirm=true}}}}.navigationTitle("Shift task").toolbar {ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button("Save"){Task {do {let new=original.id == "new";_ = try await store.send(new ? "/api/tasks" : "/api/tasks/\(original.id)",method:new ? "POST" : "PATCH",body:task);await store.load();dismiss()}catch {store.report(error)}}}.disabled(store.saving || task["title"].text.isEmpty)}}.task {task=original}.confirmationDialog("Delete this recurring task?",isPresented:$confirm,titleVisibility:.visible){Button("Delete",role:.destructive){Task {do {_ = try await store.send("/api/tasks/\(original.id)",method:"DELETE");await store.load();dismiss()}catch {store.report(error)}}}}} }
}
struct NativeParties:View {
    @EnvironmentObject var store:NativeStore
    @State private var month=String(HOPDay.today.prefix(7))+"-01"
    @State private var selectedDay=HOPDay.today
    @State private var editing:J?
    @State private var export:NativeDocument?
    @State private var showContacts=false
    var monthEnd:String {guard let date=HOPDay.parse(month),let next=HOPDay.calendar.date(byAdding:.month,value:1,to:date) else {return month};return HOPDay.add(HOPDay.iso(next),-1)}
    var path:String {"/api/parties?from=\(month)&to=\(monthEnd)"}
    var parties:[J] {store.items(path,"parties")}
    var dates:[String] {let start=HOPDay.add(month,-max(0,HOPDay.weekday(month)));return (0..<42).map {HOPDay.add(start,$0)}}
    var body:some View {NativeScreen(title:"Party calendar",subtitle:"A full month of reservations, with room for additions on the printed board.") {HStack {Button {move(-1)}label:{Image(systemName:"chevron.left")};Text(HOPDay.label(month,"MMMM yyyy")).font(.title2.bold());Button {move(1)}label:{Image(systemName:"chevron.right")};Spacer();Button("Print selected week"){Task {do {let week=HOPDay.week(selectedDay);let value=try await store.api.request("/api/parties?from=\(week)&to=\(HOPDay.add(week,5))");export=NativePDF.parties(value.list("parties"),week:week)}catch {store.report(error)}}}.buttonStyle(.bordered);Button("New party"){editing = .object(["id":.s("new"),"date":.s(selectedDay),"time":.s("17:00"),"status":.s("Booked"),"area":.s("BR"),"count":.n(10)])}.buttonStyle(.borderedProminent)}
        HStack {Button {showContacts=true}label:{Label("Customer contacts",systemImage:"person.crop.rectangle.stack")}.buttonStyle(.borderedProminent);Text("Find a returning customer and reuse their contact details.").font(.subheadline).foregroundStyle(.secondary);Spacer()}
        LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:6),count:7),spacing:6) {ForEach(["Sun","Mon","Tue","Wed","Thu","Fri","Sat"],id:\.self){Text($0).font(.caption.bold()).frame(maxWidth:.infinity)};ForEach(dates,id:\.self){date in let count=parties.filter {String($0["date"].text.prefix(10)) == date}.count;Button {selectedDay=date}label:{VStack(alignment:.leading,spacing:10){Text(HOPDay.label(date,"d")).font(.headline);if count>0 {Text("\(count) \(count == 1 ? "party" : "parties")").font(.caption).foregroundStyle(HOPStyle.green)}else {Text(" ").font(.caption)}}.padding(12).frame(maxWidth:.infinity,minHeight:78,alignment:.topLeading).background(selectedDay == date ? HOPStyle.green.opacity(0.16) : Color(.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:12)).opacity(date.prefix(7) == month.prefix(7) ? 1 : 0.35)}.buttonStyle(.plain)}}
        HOPPanel(title:HOPDay.label(selectedDay,"EEEE, MMMM d")){let list=parties.filter {String($0["date"].text.prefix(10)) == selectedDay};if list.isEmpty {Text("No bookings on this day").foregroundStyle(.secondary)};ForEach(list){party in Button {editing=party}label:{HStack {Text(party["time"].text).font(.title3.bold()).frame(width:90);VStack(alignment:.leading,spacing:5){Text(party.displayName).font(.headline);Text("\(party["count"].text) guests · \(party["area"].text) · \(party["phone"].text)").foregroundStyle(.secondary)};Spacer();StatusTag(value:party.statusText);Image(systemName:"chevron.right")}.padding(.vertical,10)}.buttonStyle(.plain)}}
    }.task(id:month){await store.load(extra:[path])}.sheet(item:$editing){NativePartyEditor(original:$0,refreshPath:path)}.sheet(item:$export){NativeDocumentPreview(document:$0)}.sheet(isPresented:$showContacts){NativePartyContacts(current:parties,day:selectedDay){contact in editing = .object(["id":.s("new"),"name":contact["name"],"phone":contact["phone"],"date":.s(selectedDay),"time":.s("17:00"),"status":.s("Booked"),"area":.s(contact.first("last_area","area").isEmpty ? "BR" : contact.first("last_area","area")),"count":.n(max(1,contact["last_party_count"].int))])}} }
    func move(_ offset:Int){if let date=HOPDay.parse(month),let next=HOPDay.calendar.date(byAdding:.month,value:offset,to:date){month=HOPDay.iso(next);selectedDay=month}}
}
struct NativePartyContacts:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) var dismiss
    var current:[J];var day:String;var choose:(J)->Void
    @State private var search=""
    @State private var selected:J?
    var path:String {"/api/parties/contacts?week_start=\(HOPDay.add(HOPDay.week(HOPDay.today),7))&limit=250"}
    var contacts:[J] {
        var result:[String:J]=[:]
        for contact in store.items(path,"contacts")+current {
            let phone=contact["phone"].text.filter(\.isNumber)
            let key=phone.isEmpty ? contact["name"].text.lowercased() : phone
            if result[key] == nil {result[key]=contact.set(["id":.s(key)])}
        }
        return result.values.filter {search.isEmpty || ($0["name"].text+" "+$0["phone"].text).localizedCaseInsensitiveContains(search)}.sorted {$0["name"].text.localizedCaseInsensitiveCompare($1["name"].text) == .orderedAscending}
    }
    var body:some View {NavigationStack {List {
        Section {Text("Returning customers from booking history, plus this month's bookings. Up to 250 historical contacts; no separate address book is created.").font(.subheadline).foregroundStyle(.secondary)}
        if let failure=store.failures[path] {Section {ErrorNote(text:failure);Button("Retry"){Task {await store.load(extra:[path])}}}}
        if contacts.isEmpty {Text(store.loading ? "Loading contacts…" : "No matching contacts")}
        ForEach(contacts) {contact in Section {
            HStack {PersonMark(name:contact["name"].text);VStack(alignment:.leading,spacing:6){Text(contact["name"].text).font(.headline);Text(contact["phone"].text.isEmpty ? "No phone saved" : contact["phone"].text).foregroundStyle(.secondary).textSelection(.enabled)};Spacer();Button("New booking"){selected=contact;dismiss()}.buttonStyle(.bordered)}
            if !contact["last_party_date"].text.isEmpty {Text("\(contact["party_count"].int) bookings · Last party \(HOPDay.label(contact["last_party_date"].text))").font(.footnote).foregroundStyle(.secondary)}
            let number=contact["phone"].text.filter { $0.isNumber || $0 == "+" }
            if !number.isEmpty,let url=URL(string:"tel:\(number)") {Link(destination:url){Label("Call customer",systemImage:"phone")}}
        }}
    }.searchable(text:$search,prompt:"Name or phone").navigationTitle("Party contacts").toolbar {Button("Done"){dismiss()}}.task {await store.load(extra:[path])}.onDisappear {if let selected {choose(selected)}}} }
}
struct NativePartyEditor:View {
    @EnvironmentObject var store:NativeStore;@Environment(\.dismiss) var dismiss;var original:J;var refreshPath:String
    @State private var party:J = .null
    var body:some View {NavigationStack {Form {RecordFields(record:$party,fields:[.init(key:"name",title:"Customer"),.init(key:"phone",title:"Phone"),.init(key:"date",title:"Date",kind:.date),.init(key:"time",title:"Time (HH:mm)"),.init(key:"count",title:"Guests",kind:.number),.init(key:"area",title:"Area",kind:.choice(["BR","B","C"])),.init(key:"status",title:"Status",kind:.choice(["Booked","Confirmed","Completed","Cancelled"])),.init(key:"notes",title:"Notes",kind:.paragraph)]);Picker("Assigned server",selection:Binding(get:{party["assigned_waitress_id"].text},set:{party["assigned_waitress_id"] = $0.isEmpty ? .null : .s($0)})){Text("Unassigned").tag("");ForEach(store.employees.filter {$0["status"].text == "active"}){Text($0.displayName).tag($0.id)}}}.navigationTitle("Party details").toolbar {ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button("Save"){Task {do {let new=original.id == "new";_ = try await store.send(new ? "/api/parties" : "/api/parties/\(original.id)",method:new ? "POST" : "PATCH",body:party);await store.load(extra:[refreshPath]);dismiss()}catch {store.report(error)}}}.disabled(store.saving || party["name"].text.isEmpty)}}.task {party=original}} }
}
struct NativeReports:View {
    @EnvironmentObject var store:NativeStore
    var schedule:J {store.schedule("published")}
    var labor:[LaborLine] {LaborLine.make(schedule:schedule,employees:store.employees)}
    var hours:Double {labor.map(\.hours).reduce(0,+)}
    var pay:Int {labor.map(\.pay).reduce(0,+)}
    var docs:[J] {store.items("/api/invoices","invoices").filter {let date=String($0["issue_date"].text.prefix(10));return date>=store.week && date<=HOPDay.add(store.week,6) && $0["document_type"].text.lowercased() != "quote" && !["void","cancelled","archived"].contains($0.statusText.lowercased())}}
    var invoiceTotal:Int {docs.map {$0["total_cents"].int}.reduce(0,+)}
    var body:some View {NativeScreen(title:"This week, at a glance",subtitle:"Published schedule · \(HOPDay.label(store.week,"MMM d")) – \(HOPDay.label(HOPDay.add(store.week,6),"MMM d"))") {
        WeekControl()
        LazyVGrid(columns:[GridItem(.adaptive(minimum:200),spacing:16)],spacing:16) {
            metric("Scheduled hours",String(format:"%.1f",hours),"clock",note:"\(labor.count) assigned shifts")
            metric("Estimated labor",HOPMoney.show(pay),"person.2",note:"\(Set(labor.map(\.employeeID)).count) people · role-based rates")
            metric("Invoices issued",HOPMoney.show(invoiceTotal),"doc.text",note:"\(docs.count) invoices · not revenue collected")
        }
        if schedule.isNull {ErrorNote(text:"No published schedule for this week. Labor estimates exclude drafts.")}
        if labor.contains(where:{$0.missingRate}) {ErrorNote(text:"Some assigned roles have no saved pay rate. Their hours are included, but estimated labor is incomplete.")}
        HOPPanel(title:"Staffing rhythm",subtitle:"Scheduled hours by day · Tuesday through Sunday") {
            HStack(alignment:.bottom,spacing:18) {ForEach(HOPDay.days(store.week),id:\.self) {day in dayBar(day)}}.frame(height:170)
        }
        HOPPanel(title:"Team & role breakdown",subtitle:"Tap a person for shift, role, hours and hourly rate. Estimates are not clocked payroll.") {
            if labor.isEmpty {Text("No published assignments").foregroundStyle(.secondary)}
            ForEach(store.employees.filter {person in labor.contains {$0.employeeID == person.id}}) {person in employeeRow(person);Divider()}
        }
        HOPPanel(title:"Invoice activity",subtitle:"Issued during this week · quotes and voided / archived records excluded") {
            if docs.isEmpty {Text("No invoices issued this week").foregroundStyle(.secondary)}
            ForEach(docs) {doc in HStack(spacing:16) {Image(systemName:"doc.text").foregroundStyle(HOPStyle.teal);VStack(alignment:.leading,spacing:5) {Text(doc["customer_name"].text).font(.headline);Text(doc.first("invoice_number","document_number")+" · "+HOPDay.label(doc["issue_date"].text)).font(.caption).foregroundStyle(.secondary)};Spacer();StatusTag(value:doc.statusText);Text(HOPMoney.show(doc["total_cents"].int)).font(.headline).monospacedDigit()}.padding(.vertical,8)}
            Divider();DetailPair(title:"Issued total",value:HOPMoney.show(invoiceTotal))
        }
    } }
    private func metric(_ title:String,_ value:String,_ icon:String,note:String)->some View {HOPPanel {Label(title,systemImage:icon).font(.subheadline).foregroundStyle(HOPStyle.teal);Text(value).font(.system(size:30,weight:.bold,design:.rounded)).minimumScaleFactor(0.7).lineLimit(1);Text(note).font(.caption).foregroundStyle(.secondary)}}
    private func dayBar(_ day:String)->some View {
        let value=labor.filter {$0.weekday == HOPDay.weekday(day)}.map(\.hours).reduce(0,+)
        let highest=HOPDay.days(store.week).map {d in labor.filter {$0.weekday == HOPDay.weekday(d)}.map(\.hours).reduce(0,+)}.max() ?? 1
        return VStack(spacing:8) {Text(String(format:"%.1fh",value)).font(.caption.bold());RoundedRectangle(cornerRadius:7).fill(HOPStyle.green.gradient).frame(height:CGFloat(value/max(1,highest))*115+2);Text(HOPDay.label(day,"EEE")).font(.subheadline.bold());Text(HOPDay.label(day,"MMM d")).font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity)
    }
    private func employeeRow(_ person:J)->some View {
        let lines=labor.filter {$0.employeeID == person.id}
        return DisclosureGroup {ForEach(lines) {line in HStack {VStack(alignment:.leading,spacing:4) {Text(["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][max(0,min(6,line.weekday))]+" · "+line.role.capitalized+" · "+line.slot).font(.subheadline.bold());Text(String(format:"%.1fh",line.hours)+" × "+(line.missingRate ? "Rate not set" : HOPMoney.show(line.rate)+"/h")).font(.caption).foregroundStyle(.secondary)};Spacer();Text(HOPMoney.show(line.pay)).monospacedDigit()}.padding(.vertical,7)}} label:{HStack {PersonMark(name:person.displayName);VStack(alignment:.leading,spacing:4) {Text(person.displayName).font(.headline);Text(String(format:"%.1f hours",lines.map(\.hours).reduce(0,+))).font(.caption).foregroundStyle(.secondary)};Spacer();Text(HOPMoney.show(lines.map(\.pay).reduce(0,+))).font(.headline).monospacedDigit()}}.padding(.vertical,7)
    }
}
