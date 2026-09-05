import SwiftUI

struct ShiftSelection:Identifiable { var row:J; var day:String; var id:String {row.id+day} }
struct NativeSchedule:View {
    @EnvironmentObject var store:NativeStore
    @State private var mode="published"
    @State private var board="Main"
    @State private var selected:ShiftSelection?
    @State private var publish=false
    @State private var confirmCopy=false
    @State private var export:NativeDocument?
    var schedule:J {store.schedule(mode)}
    var rows:[J] {schedule["rows"].array.filter {board == "Host" ? $0["role_group"].text == "host" : $0["role_group"].text != "host"}.sorted {$0["sort_order"].int < $1["sort_order"].int}}
    var body:some View { VStack(spacing:0) {
        VStack(alignment:.leading,spacing:16) {
            ViewThatFits(in:.horizontal) { HStack {WeekControl(); Spacer(); controls}; VStack(alignment:.leading) {WeekControl();controls} }
            HStack { Picker("Version",selection:$mode) {Text("Published").tag("published");Text("Draft").tag("draft")}.pickerStyle(.segmented).frame(maxWidth:320); Picker("Department",selection:$board) {Text("Main & floor").tag("Main");Text("Host").tag("Host")}.pickerStyle(.segmented).frame(maxWidth:300); Spacer() }
            Label(mode == "published" ? "Published · Read-only for employee safety" : "Draft · Only managers can see these changes",systemImage:mode == "published" ? "lock.shield" : "pencil.line").font(.subheadline).foregroundStyle(.secondary)
        }.padding(24)
        if schedule.isNull { NativeEmpty(title:mode == "published" ? "No published schedule" : "No draft for this week",detail:"Create an empty draft or edit a copy of the published week.",icon:"calendar"); Spacer() }
        else { ScrollView([.horizontal,.vertical]) { VStack(spacing:0) {
            HStack(spacing:0) {Text("SHIFT").frame(width:110); ForEach(HOPDay.days(store.week),id:\.self) {day in Text(HOPDay.label(day,"EEE\nMMM d")).multilineTextAlignment(.center).frame(width:158).padding(.vertical,16)} }.font(.subheadline.bold()).background(.background)
            ForEach(rows) {row in HStack(spacing:0) {
                VStack(alignment:.leading,spacing:8) {Text(row["label"].text).font(.headline); Text(row["role_group"].text.capitalized).font(.caption).foregroundStyle(.secondary)}.frame(width:90,alignment:.leading).padding(10).frame(maxHeight:.infinity).background(HOPStyle.band(row).opacity(0.1))
                ForEach(HOPDay.days(store.week),id:\.self) {day in cell(row,day)}
            }.fixedSize(horizontal:false,vertical:true); Divider() }
        }.clipShape(RoundedRectangle(cornerRadius:18)).padding(.horizontal,24).padding(.bottom,24) } }
    }.sheet(item:$selected) {value in NativeShiftEditor(selection:value,schedule:schedule,editable:mode == "draft")}
    .sheet(isPresented:$publish) {NativePublish(schedule:schedule)}
    .sheet(item:$export) {NativeDocumentPreview(document:$0)}
    .confirmationDialog("Copy last week into this draft? Existing draft assignments may be replaced.",isPresented:$confirmCopy,titleVisibility:.visible) {Button("Copy previous week",role:.destructive) {act("/api/schedules/draft/\(schedule.id)/copy-previous")}}
    .onChange(of:store.week) {_,_ in selected=nil}
    }
    private var controls:some View { HStack {
        Menu { Button("New empty draft") {act("/api/schedules/draft/empty")}; Button("Edit published copy") {act("/api/schedules/draft/from-published")}; if mode == "draft" && !schedule.isNull {Button("Copy previous week") {confirmCopy=true}} } label:{Label("Draft",systemImage:"plus")}.buttonStyle(.bordered)
        Button {export=NativePDF.schedule(schedule,week:store.week,rows:rows,employees:store.employees,parties:store.items("/api/parties?from=\(store.week)&to=\(HOPDay.add(store.week,20))","parties"))} label:{Label("Export",systemImage:"square.and.arrow.up")}.buttonStyle(.bordered).disabled(schedule.isNull)
        if mode == "draft" {Button("Review & publish") {publish=true}.buttonStyle(.borderedProminent).disabled(schedule.isNull || store.saving)}
    } }
    private func cell(_ row:J,_ day:String) -> some View {
        let entries=BoardRules.entries(schedule,row:row,day:day),assigned=entries.filter {!$0["employee_id"].text.isEmpty},closed=BoardRules.cellClosed(entries,row:row,day:day)
        return Button {selected=ShiftSelection(row:row,day:day)} label: {
            VStack(alignment:.leading,spacing:7) {
                if closed {Text("—").font(.title2).foregroundStyle(.secondary).frame(maxWidth:.infinity,minHeight:48)}
                else if assigned.isEmpty {Text("Open shift").font(.subheadline.bold()).foregroundStyle(.orange); Text("Tap to view").font(.caption).foregroundStyle(.secondary)}
                else {ForEach(assigned) {entry in HStack(alignment:.top) {VStack(alignment:.leading,spacing:5) {Text(store.name(entry["employee_id"].text)).font(.subheadline.bold()).lineLimit(2); Text("\(String(entry["start_time"].text.prefix(5))) – \(String(entry["end_time"].text.prefix(5)))").font(.caption).monospacedDigit().foregroundStyle(.secondary)};Spacer(minLength:2);if schedule["entries"].array.filter({$0["employee_id"] == entry["employee_id"] && $0["day_of_week"] == entry["day_of_week"]}).count>1 {Text("×2").font(.caption2.bold()).padding(4).foregroundStyle(.white).background(Color.blue,in:Capsule())} } } }
            }.padding(12).frame(width:150).frame(minHeight:82,alignment:.leading).background(closed ? Color.secondary.opacity(0.04) : assigned.isEmpty ? Color.orange.opacity(0.05) : HOPStyle.band(row).opacity(0.06),in:RoundedRectangle(cornerRadius:12)).padding(4).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("\(row["label"].text), \(HOPDay.label(day)), \(closed ? "Closed" : assigned.isEmpty ? "Open shift" : assigned.map {store.name($0["employee_id"].text)}.joined(separator:", "))")
    }
    private func act(_ path:String) {Task {do {_ = try await store.send(path,body:.object(["week_start_date":.s(store.week),"actor_id":.s(store.manager.id)]));mode="draft";await store.load()}catch {store.report(error)}}}
}
struct NativeShiftEditor:View {
    @EnvironmentObject var store:NativeStore; @Environment(\.dismiss) var dismiss
    var selection:ShiftSelection; var schedule:J; var editable:Bool
    @State private var entry:J = .object([:]); @State private var showAll=false
    @State private var closeConfirm=false
    @State private var checking=false
    var availabilityPath:String {"/api/availability?week_start=\(HOPDay.week(selection.day))"}
    var availabilityReady:Bool {guard let payload=store.data[availabilityPath],case .array = payload["availability"] else {return false};return store.failures[availabilityPath] == nil}
    var entries:[J] {BoardRules.entries(schedule,row:selection.row,day:selection.day)}
    var assigned:[J] {entries.filter {!$0["employee_id"].text.isEmpty}}
    var candidates:[J] {store.employees.filter {person in person.id == entry["employee_id"].text || (person["status"].text == "active" && (showAll || (availabilityReady && BoardRules.roleMatch(person,selection.row) && availability(person) != "off" && !BoardRules.overlaps(candidate.set(["employee_id":.s(person.id)]),schedule["entries"].array)))) }.sorted {$0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending}}
    func availability(_ person:J)->String {BoardRules.availabilityState(person,day:selection.day,row:selection.row,availability:store.items(availabilityPath,"availability"),start:entry["start_time"].text)}
    func candidateLabel(_ person:J)->String {
        if !availabilityReady {return "Availability not loaded"}
        if person["status"].text != "active" {return "Inactive"}
        if !BoardRules.roleMatch(person,selection.row) {return "Role mismatch"}
        if BoardRules.overlaps(candidate.set(["employee_id":.s(person.id)]),schedule["entries"].array) {return "Overlapping shift"}
        return availability(person) == "off" ? "Marked off" : availability(person) == "available" ? "Available" : "Default · no submission"
    }
    var selectedOff:Bool {store.employees.first(where:{$0.id == entry["employee_id"].text}).map {availability($0) == "off"} ?? false}
    var closed:Bool {BoardRules.cellClosed(entries,row:selection.row,day:selection.day)}
    var candidate:J {entry.set(["row_id":.s(selection.row.id),"day_of_week":.n(HOPDay.weekday(selection.day)),"role":selection.row["role_group"],"notes":.s(BoardRules.activeNotes(entry)),"updated_by":.s(store.manager.id)])}
    var overlap:Bool {BoardRules.overlaps(candidate,schedule["entries"].array)}
    var body:some View {NavigationStack {Form {
        Section {Text(HOPDay.label(selection.day,"EEEE, MMMM d")).font(.title2.bold()); StatusTag(value:editable ? "Draft" : "Published"); if !editable {Text("This is the published version. Use “Edit published copy” to make safe changes.").foregroundStyle(.secondary)}}
        Section("Assigned") {if assigned.isEmpty {Text("No employee assigned").foregroundStyle(.secondary)}; ForEach(assigned) {person in Button {entry=person} label:{HStack {PersonMark(name:store.name(person["employee_id"].text)); VStack(alignment:.leading) {Text(store.name(person["employee_id"].text)); Text("\(person["start_time"].text) – \(person["end_time"].text)").font(.caption)};Spacer(); if entry.id == person.id {Image(systemName:"checkmark.circle.fill")}}}.disabled(!editable)} }
        if editable {Section("Assignment & time") {
            Label("\(HOPDay.label(selection.day)) · \(BoardRules.shiftKey(selection.row,start:entry["start_time"].text)) availability",systemImage:"calendar.badge.checkmark").foregroundStyle(HOPStyle.green)
            Text("Matched staff only: active, qualified for this role, not marked off, and no overlapping shift. No submission uses the server's default availability.").font(.footnote).foregroundStyle(.secondary)
            if !availabilityReady {ErrorNote(text:"Availability could not be loaded. Refresh before assigning staff.");Button("Reload availability"){Task {await store.load(extra:[availabilityPath])}}}
            Toggle("Show excluded staff and reasons",isOn:$showAll)
            Picker("Employee",selection:Binding(get:{entry["employee_id"].text},set:{entry["employee_id"] = .s($0)})) {Text("Open shift").tag("");ForEach(candidates) {person in Text(person.displayName+" · "+candidateLabel(person)).tag(person.id)}}
            time("Start",key:"start_time"); time("End",key:"end_time")
            if overlap {ErrorNote(text:"This employee already has an overlapping shift. Choose another employee or adjust the time.")}
            else if selectedOff {ErrorNote(text:"This employee is marked off for this shift. Choose an available employee, or resolve their availability before assigning.")}
            Button(checking ? "Checking latest availability…" : "Save assignment") {save(candidate)}.disabled(store.saving || checking || !availabilityReady || selectedOff || overlap || entry["end_time"].text <= entry["start_time"].text)
            Button("Add another employee") {reset()}
        }
        Section {Button(closed ? "Reopen cell" : "Close cell",role:.destructive) {closeConfirm=true}.disabled(assigned.count>1);if assigned.count>1 {Text("Remove extra assignments before closing this cell.").font(.footnote)}; if !entry.id.isEmpty {Button("Remove selected assignment",role:.destructive) {Task {do {_ = try await store.send("/api/schedules/draft/\(schedule.id)/entries/\(entry.id)",method:"DELETE");await store.load();dismiss()}catch {store.report(error)}}}} }
    }}.navigationTitle(selection.row["label"].text).toolbar {Button("Done") {dismiss()}}.task {if let first=assigned.first {entry=first}else{reset();entry["id"]=entries.first?["id"] ?? .null}}
    .confirmationDialog("\(closed ? "Reopen" : "Close") this cell? Closing removes its assignment.",isPresented:$closeConfirm,titleVisibility:.visible) {Button("Confirm",role:.destructive) {save(candidate.set(["employee_id":.null,"start_time":.null,"end_time":.null,"notes":.s(closed ? "HOP_SLOT_ACTIVE" : "HOP_SLOT_INACTIVE")]))}} }
    }
    private func reset() {let times=BoardRules.defaults(selection.row);entry = .object(["id":.null,"employee_id":.s(""),"start_time":.s(times.0),"end_time":.s(times.1)])}
    private func time(_ title:String,key:String)->some View {DatePicker(title,selection:Binding(get:{let f=DateFormatter();f.dateFormat="HH:mm";return f.date(from:String(entry[key].text.prefix(5))) ?? Date()},set:{let f=DateFormatter();f.dateFormat="HH:mm";entry[key] = .s(f.string(from:$0))}),displayedComponents:.hourAndMinute)}
    private func save(_ value:J) {Task {checking=true;defer {checking=false};do {
        if !value["employee_id"].text.isEmpty {
            let latest=try await store.api.request(availabilityPath)
            guard case .array = latest["availability"] else {throw NativeFailure(status:0,message:"Availability returned an incomplete response. No assignment was saved; refresh and try again.")}
            store.data[availabilityPath]=latest;store.failures[availabilityPath]=nil
            guard let person=store.employees.first(where:{$0.id == value["employee_id"].text}),person["status"].text == "active",BoardRules.roleMatch(person,selection.row) else {throw NativeFailure(status:0,message:"Choose an active employee qualified for this role.")}
            guard BoardRules.availabilityState(person,day:selection.day,row:selection.row,availability:latest.list("availability"),start:value["start_time"].text) != "off" else {throw NativeFailure(status:0,message:"\(person.displayName) is now marked off. Availability was refreshed; choose another employee.")}
        }
        _ = try await store.send("/api/schedules/draft/\(schedule.id)/entries",body:value);await store.load();dismiss()
    }catch {store.report(error)}}}
}
struct NativePublish:View {
    @EnvironmentObject var store:NativeStore; @Environment(\.dismiss) var dismiss; var schedule:J
    @State private var note=""
    @State private var pin=""
    @State private var conflict=""
    @State private var canOverride=false
    var body:some View {NavigationStack {Form {Section {Label("Publish to the employee app",systemImage:"person.2.wave.2").font(.headline);Text("This makes the draft visible to staff. Review the week and assignments before continuing.");Text(HOPDay.label(store.week)+" · \(schedule["entries"].array.filter {!$0["employee_id"].text.isEmpty}.count) assignments")};Section("Publish note") {TextEditor(text:$note).frame(height:90)};if !conflict.isEmpty {Section {ErrorNote(text:conflict)}};if canOverride {Section("Manager-authorized exception") {SecureField("Your manager PIN",text:$pin).keyboardType(.numberPad);Text("Only overridable conflicts can be approved. Genuine overlapping shifts remain blocked.")}}}.navigationTitle("Review & publish").toolbar {ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button(canOverride ? "Override & publish" : "Publish") {Task {do {_ = try await store.send("/api/schedules/\(schedule.id)/publish",body:.object(["publish_notes":.s(note),"override_conflicts":.bool(canOverride),"manager_pin":.s(pin)]));pin="";await store.load();dismiss()}catch {pin="";conflict=error.localizedDescription;canOverride=(error as? NativeFailure)?.payload["can_override"].truth ?? false}}}.disabled(store.saving || (canOverride && pin.isEmpty))}}} }
}
