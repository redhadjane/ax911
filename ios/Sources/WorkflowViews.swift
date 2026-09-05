import SwiftUI
import PhotosUI
import UIKit

struct RequestsView: View {
    @EnvironmentObject private var store: HOPStore
    @State private var history = false
    @State private var compose = false
    @State private var swap = false
    @State private var selected: HOPRecord?
    @State private var hidden = Set<String>()
    private let terminal = ["approved", "denied", "cancelled", "declined_by_target"]
    private var requests: [HOPRecord] {
        var seen = Set<String>()
        return (store.records("pending", "requests") + store.records("history", "requests")).filter { seen.insert($0.id).inserted && terminal.contains($0.status) == history && !hidden.contains($0.id) }
    }
    private var switches: [HOPRecord] { store.records("swaps", "shift_switches").filter { terminal.contains($0.status) == history && !hidden.contains($0.id) } }
    private var storageKey: String { "hopHiddenRequests.\(store.employee?.id ?? "")" }
    var body: some View {
        ScrollView { LazyVStack(spacing: 18) {
            Picker("Requests", selection: $history) { Text("In progress").tag(false); Text("History").tag(true) }.pickerStyle(.segmented)
            HStack { Button("New request", systemImage: "plus") { compose = true }.buttonStyle(.borderedProminent); Button("Switch shift", systemImage: "arrow.left.arrow.right") { swap = true }.buttonStyle(.bordered) }.controlSize(.large)
            HOPError(section: "pending"); HOPError(section: "history"); HOPError(section: "swaps")
            if store.loading && store.data["pending"] == nil { ProgressView("Loading requests…") }
            else if requests.isEmpty && switches.isEmpty && store.errors["pending"] == nil && store.errors["swaps"] == nil { HOPEmpty(title: history ? "No history in this view" : "Nothing awaiting a decision", detail: history ? "Completed requests remain saved with HOP even if you hide them here." : "Request time off, extra work, or a shift switch. Your manager's decision will appear here.", icon: "arrow.left.arrow.right") }
            ForEach(switches) { item in SwitchRequestCard(record: item) }
            ForEach(requests) { item in
                Button { selected = item } label: {
                    HOPCard {
                        HStack(alignment: .top) { Text(requestName(item.first("type", "request_type"))).font(.headline); Spacer(); HOPStatus(value: item.status) }
                        Text(requestDates(item)).font(.subheadline).foregroundStyle(.secondary)
                        if !item.first("note", "message").isEmpty { Text(item.first("note", "message")).font(.subheadline).lineLimit(3) }
                        Label("View details and decisions", systemImage: "chevron.right").font(.caption).foregroundStyle(HOPStyle.green)
                    }
                }.buttonStyle(.plain)
            }
            if history {
                Button("Hide completed history on this iPhone") { hidden.formUnion(requests.map(\.id)); hidden.formUnion(switches.map(\.id)); UserDefaults.standard.set(Array(hidden), forKey: storageKey) }.disabled(requests.isEmpty && switches.isEmpty).frame(minHeight: 44)
                if !hidden.isEmpty { Button("Show hidden history") { hidden = []; UserDefaults.standard.removeObject(forKey: storageKey) }.frame(minHeight: 44) }
            }
        }.padding(20) }.background(HOPStyle.background).navigationTitle("Requests").refreshable { await store.refresh() }
        .onAppear { hidden = Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? []) }
        .sheet(isPresented: $compose) { NavigationStack { NewRequestView() } }
        .sheet(isPresented: $swap) { NavigationStack { ShiftSwitchView(initialShiftID: "") } }
        .sheet(item: $selected) { item in NavigationStack { RequestDetailView(record: item) } }
    }
}
func requestName(_ type: String) -> String {
    ["day_off": "Day off", "off": "Day off", "vacation": "Vacation", "sick": "Sick leave", "sick_note": "Sick note", "extra_shift": "Extra work", "availability_change": "Availability change", "general": "General request", "shift_switch": "Shift switch"][type] ?? type.replacingOccurrences(of: "_", with: " ").capitalized
}
func requestDates(_ record: HOPRecord) -> String {
    let dates = record["payload"]["dates"].records
    if !dates.isEmpty { return dates.map { HOPCalendar.label($0["date"].text) + ($0["time"].text.isEmpty ? "" : " · " + HOPCalendar.clock($0["time"].text)) }.joined(separator: "; ") }
    let start = record.first("start_date", "date"), end = record["end_date"].text
    if start.isEmpty { return "No specific date" }
    return HOPCalendar.label(start) + (!end.isEmpty && end.prefix(10) != start.prefix(10) ? " – " + HOPCalendar.label(end) : "")
}

struct RequestDetailView: View {
    @EnvironmentObject private var store: HOPStore
    @Environment(\.dismiss) private var dismiss
    let record: HOPRecord
    @State private var cancel = false
    var body: some View {
        List {
            Section {
                HOPStatus(value: record.status); Text(requestDates(record)); Text(record.first("note", "message")).textSelection(.enabled)
                if !record["created_at"].text.isEmpty { LabeledContent("Submitted", value: String(record["created_at"].text.prefix(10))) }
            }
            if !record["items"].records.isEmpty {
                Section("Date-by-date decisions") {
                    ForEach(record["items"].records) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(HOPCalendar.label(item.first("item_date", "date", "request_date"))).font(.headline); HOPStatus(value: item.status)
                            if !item.first("manager_note", "note").isEmpty { Text(item.first("manager_note", "note")).font(.subheadline) }
                        }.padding(.vertical, 6)
                    }
                }
            }
            Section("Manager response") { Text(record["manager_note"].text.isEmpty ? (record.status == "pending" ? "Waiting for manager review. Your schedule does not change until the request is approved." : "No additional manager note.") : record["manager_note"].text) }
            if ["pending", "employee_approved"].contains(record.status) { Section { Button("Cancel this request", role: .destructive) { cancel = true }.disabled(store.busy) } }
        }.navigationTitle(requestName(record.first("type", "request_type"))).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        .confirmationDialog("Cancel this request?", isPresented: $cancel, titleVisibility: .visible) { Button("Cancel request", role: .destructive) { Task { if await store.act("/api/requests/\(record.id)/cancel", body: ["employee_id": .string(store.employee?.id ?? "")], success: "Request cancelled.") { dismiss() } } } }
    }
}

struct RequestDate: Identifiable {
    let date: String; let time: String
    var id: String { date + time }
    var json: JSONValue { .object(["date": .string(date), "time": .string(time)]) }
}
struct NewRequestView: View {
    @EnvironmentObject private var store: HOPStore
    @Environment(\.dismiss) private var dismiss
    @State private var kind = "day_off"
    @State private var note = ""
    @State private var date = Date()
    @State private var time = Date()
    @State private var timed = false
    @State private var dates: [RequestDate] = []
    @State private var error: String?
    private var requiresDate: Bool { ["day_off", "vacation", "sick", "extra_shift", "availability_change"].contains(kind) }
    var body: some View {
        Form {
            Section("What do you need?") {
                Picker("Request", selection: $kind) { ForEach(["day_off", "vacation", "sick", "extra_shift", "availability_change", "general"], id: \.self) { Text(requestName($0)).tag($0) } }
            }
            Section {
                DatePicker("Choose date", selection: $date, displayedComponents: .date)
                Toggle("Include a time", isOn: $timed)
                if timed { DatePicker("Time (Eastern)", selection: $time, displayedComponents: .hourAndMinute) }
                Button("Add date", systemImage: "plus.circle") {
                    let f = DateFormatter(); f.timeZone = HOPCalendar.zone; f.dateFormat = "HH:mm"
                    let value = RequestDate(date: HOPCalendar.key(date), time: timed ? f.string(from: time) : "")
                    if !dates.contains(where: { $0.id == value.id }) { dates.append(value); dates.sort { $0.id < $1.id } }
                }
                ForEach(dates) { day in HStack { Text(HOPCalendar.label(day.date) + (day.time.isEmpty ? "" : " · " + HOPCalendar.clock(day.time))); Spacer(); Button(role: .destructive) { dates.removeAll { $0.id == day.id } } label: { Image(systemName: "minus.circle").frame(width: 44, height: 44) }.accessibilityLabel("Remove \(HOPCalendar.label(day.date))") } }
            } header: { Text(requiresDate ? "Dates · Required" : "Dates · Optional") } footer: { Text("Add each date you need. Only the listed dates are sent, not the days between them. Times are Eastern.") }
            Section("Details for your manager") { TextField("What should your manager know?", text: $note, axis: .vertical).lineLimit(4...8) }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            Section { Button { Task { await submit() } } label: { HStack { if store.busy { ProgressView() }; Text("Send for review").fontWeight(.semibold) }.frame(maxWidth: .infinity, minHeight: 36) }.disabled(store.busy || (requiresDate && dates.isEmpty) || note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } footer: { Text("Your manager will review this request. Submitting it does not automatically change your published schedule.") }
        }.environment(\.timeZone, HOPCalendar.zone).navigationTitle("New request").navigationBarTitleDisplayMode(.inline).scrollDismissesKeyboard(.interactively)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.disabled(store.busy) } }.interactiveDismissDisabled(store.busy)
    }
    private func submit() async {
        let body: [String: JSONValue] = ["employee_id": .string(store.employee?.id ?? ""), "type": .string(kind), "date": dates.first.map { .string($0.date) } ?? .null, "start_date": dates.first.map { .string($0.date) } ?? .null, "end_date": dates.last.map { .string($0.date) } ?? .null, "note": .string(note.trimmingCharacters(in: .whitespacesAndNewlines)), "payload": .object(["dates": .array(dates.map(\.json)), "no_specific_date": .bool(dates.isEmpty)])]
        if await store.act("/api/requests", body: body, success: "Request sent for manager review.") { dismiss() } else { error = store.message; store.message = nil }
    }
}

struct SwitchRequestCard: View {
    @EnvironmentObject private var store: HOPStore
    let record: HOPRecord
    @State private var action: String?
    @State private var responseNote = ""
    private var isTarget: Bool { record["target_employee_id"].text == store.employee?.id }
    private var isRequester: Bool { record["requesting_employee_id"].text == store.employee?.id }
    var body: some View {
        HOPCard {
            HStack { Label("Shift switch", systemImage: "arrow.left.arrow.right").font(.headline); Spacer(); HOPStatus(value: record.status) }
            Text(isRequester ? "To \(record["target_employee_name"].text)" : "From \(record["requesting_employee_name"].text)").font(.subheadline.weight(.semibold))
            Text(record["request_reason"].text).font(.subheadline)
            if !record["week_start_date"].text.isEmpty { Text("Week of \(HOPCalendar.label(record["week_start_date"].text))").font(.caption).foregroundStyle(.secondary) }
            if !record["target_response_note"].text.isEmpty { Text("Employee response: \(record["target_response_note"].text)").font(.subheadline) }
            if !record["manager_response_note"].text.isEmpty { Text("Manager: \(record["manager_response_note"].text)").font(.subheadline) }
            if isTarget && record.status == "pending_target" {
                TextField("Optional response note", text: $responseNote, axis: .vertical).textFieldStyle(.roundedBorder)
                HStack { Button("Accept") { action = "accept" }.buttonStyle(.borderedProminent); Button("Decline", role: .destructive) { action = "decline" }.buttonStyle(.bordered) }.controlSize(.large).disabled(store.busy)
            }
            if isRequester && ["pending_target", "pending_manager", "accepted_by_target"].contains(record.status) { Button("Cancel switch", role: .destructive) { action = "cancel" }.frame(minHeight: 44).disabled(store.busy) }
            if ["pending_target", "pending_manager", "accepted_by_target"].contains(record.status) { Text("Both employee agreement and manager approval are required. The original shift stays assigned until approval.").font(.caption).foregroundStyle(.secondary) }
        }.confirmationDialog("\((action ?? "").capitalized) this shift switch?", isPresented: Binding(get: { action != nil }, set: { if !$0 { action = nil } }), titleVisibility: .visible) {
            Button((action ?? "").capitalized) {
                guard let selected = action else { return }; action = nil
                Task { _ = await store.act("/api/shift-switch/\(record.id)/\(selected)", body: ["employee_id": .string(store.employee?.id ?? ""), "target_response_note": .string(responseNote)], success: selected == "accept" ? "Accepted. Waiting for manager approval." : "Shift switch \(selected == "cancel" ? "cancelled" : "declined").") }
            }
        }
    }
}

struct ShiftSwitchView: View {
    @EnvironmentObject private var store: HOPStore
    @Environment(\.dismiss) private var dismiss
    let initialShiftID: String
    @State private var shiftID = ""
    @State private var targetID = ""
    @State private var reason = ""
    @State private var candidates: [HOPRecord] = []
    @State private var loading = false
    @State private var error: String?
    private var shifts: [HOPShift] { store.shifts.filter { ($0.endInstant ?? .distantPast) > Date() } }
    var body: some View {
        Form {
            Section("Your published shift") {
                Picker("Shift", selection: $shiftID) { Text("Choose your shift").tag(""); ForEach(shifts) { Text("\(HOPCalendar.label($0.date)) · \($0.time) · \($0.role)").tag($0.id) } }
                if shifts.isEmpty { Text("No upcoming shifts in the selected schedule week. Choose another week in Schedule first.").font(.subheadline).foregroundStyle(.secondary) }
            }
            Section("Ask a coworker") {
                if loading { ProgressView("Checking role and availability…") }
                else if !shiftID.isEmpty && candidates.isEmpty && error == nil { Text("HOP found no candidates for this shift.").foregroundStyle(.secondary) }
                ForEach(candidates, id: \.id) { person in
                    Button { targetID = person["employee_id"].text; HOPStyle.haptic() } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) { Text(person.name).font(.headline); Text(person["role"].text.capitalized).font(.caption).foregroundStyle(.secondary)
                                Text(person["recommended"].flag ? "Recommended by HOP" : "Manager review may be needed").font(.caption).foregroundStyle(person["recommended"].flag ? HOPStyle.green : .orange)
                                ForEach(person["reasons"].values.map(\.text), id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                            }; Spacer(); Image(systemName: targetID == person["employee_id"].text ? "checkmark.circle.fill" : "circle")
                        }.padding(.vertical, 6)
                    }.buttonStyle(.plain)
                }
                if let error { Text(error).foregroundStyle(.red); Button("Try again") { Task { await loadCandidates() } }.disabled(loading) }
            }
            Section("Reason") { TextField("Why do you need to switch?", text: $reason, axis: .vertical).lineLimit(3...6) }
            Section { Button("Send switch request") { Task {
                if await store.act("/api/shift-switch", body: ["schedule_entry_id": .string(shiftID), "target_employee_id": .string(targetID), "request_reason": .string(reason)], success: "Switch sent to your coworker. Manager approval is still required.") { dismiss() } else { error = store.message; store.message = nil }
            } }.disabled(shiftID.isEmpty || targetID.isEmpty || loading || store.busy) } footer: { Text("The server rechecks permissions, availability and schedule conflicts. A displayed candidate is not a guaranteed approval.") }
        }.navigationTitle("Switch a shift").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.disabled(store.busy) } }
        .onAppear { if shiftID.isEmpty { shiftID = initialShiftID } }.task(id: shiftID) { await loadCandidates() }.interactiveDismissDisabled(store.busy)
    }
    private func loadCandidates() async {
        targetID = ""; candidates = []; error = nil
        guard !shiftID.isEmpty else { loading = false; return }
        let requested = shiftID; loading = true
        do {
            let payload = try await store.api.request("/api/shift-switch/candidates/\(requested)")
            guard shiftID == requested && !Task.isCancelled else { return }
            candidates = payload["candidates"].records; loading = false
        } catch { if shiftID == requested && !Task.isCancelled { self.error = error.localizedDescription; loading = false } }
    }
}

struct AvailabilityView: View {
    @EnvironmentObject private var store: HOPStore
    @Environment(\.dismiss) private var dismiss
    @State private var week = ""
    @State private var fourWeeks = false
    @State private var matrices: [String: JSONValue] = [:]
    @State private var slots: [String: [HOPRecord]] = [:]
    @State private var dirty = Set<String>()
    @State private var loading = false
    @State private var saving = false
    @State private var error: String?
    @State private var confirmWeek: String?
    @State private var discard = false
    private let days = ["Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private var weeks: [String] { (0..<(fourWeeks ? 4 : 1)).map { HOPCalendar.add(week, days: $0 * 7) } }
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            HStack {
                Button { week = HOPCalendar.add(week, days: -7) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Earlier availability week")
                Spacer(); Text("Week of \(HOPCalendar.label(week))").font(.headline); Spacer()
                Button { week = HOPCalendar.add(week, days: 7) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("Later availability week")
            }.disabled(loading || saving || !dirty.isEmpty)
            Toggle("Show four weeks", isOn: $fourWeeks).disabled(saving || !dirty.isEmpty)
            if let error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red); Button("Reload availability") { Task { await load() } }.disabled(loading || saving) }
            if loading { ProgressView("Loading availability…").frame(maxWidth: .infinity).padding() }
            ForEach(weeks, id: \.self) { key in
                if let matrix = matrices[key] {
                    HOPSection(title: HOPCalendar.label(key, format: "MMMM d") + " – " + HOPCalendar.label(HOPCalendar.add(key, days: 5), format: "d")) {
                        HOPStatus(value: matrix["status_label"].text.isEmpty ? matrix["status"].text : matrix["status_label"].text)
                        HOPCard {
                            HStack { Text("Day").frame(width: 56); Text("Morning").frame(maxWidth: .infinity); Text("Evening").frame(maxWidth: .infinity) }.font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                                HStack(spacing: 8) {
                                    VStack(spacing: 3) { Text(day).font(.subheadline.bold()); Text(HOPCalendar.label(HOPCalendar.add(key, days: index), format: "MMM d")).font(.caption2) }.frame(width: 56)
                                    ForEach(["AM", "PM"], id: \.self) { shift in
                                        let available = value(key, day, shift)["status"].text != "off"
                                        Button { toggle(key, day, shift); HOPStyle.haptic() } label: {
                                            VStack(spacing: 5) { Image(systemName: available ? "checkmark" : "minus"); Text(available ? "Available" : "Off").font(.caption.weight(.semibold)) }.frame(maxWidth: .infinity, minHeight: 58).foregroundStyle(available ? HOPStyle.green : Color.red).background((available ? HOPStyle.green : Color.red).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                        }.buttonStyle(.plain).disabled(matrix["locked"].flag || saving || loading).accessibilityLabel("\(day) \(shift), \(available ? "available" : "off")\(matrix["locked"].flag ? ", locked" : ", tap to switch")")
                                    }
                                }
                            }
                            if matrix["locked"].flag { Label("Confirmed and locked. Ask your manager to reopen this week if it needs changing.", systemImage: "lock").font(.footnote).foregroundStyle(.secondary) }
                            else {
                                HStack {
                                    Button("Save draft") { Task { await save(key, confirm: false) } }.buttonStyle(.bordered)
                                    Button("Confirm week") { confirmWeek = key }.buttonStyle(.borderedProminent)
                                }.controlSize(.large).disabled(saving || loading)
                                if dirty.contains(key) { Text("Unsaved changes · Save or discard before changing weeks.").font(.caption).foregroundStyle(.orange); Button("Discard changes") { restoreSlots(key) }.disabled(saving) }
                            }
                        }
                    }
                }
            }
            Text("Tap once to switch Available / Off. Green is available; red is off. A saved draft can still be edited. Confirming locks the week for manager planning.").font(.footnote).foregroundStyle(.secondary)
        }.padding(20) }.background(HOPStyle.background).navigationTitle("Availability").navigationBarTitleDisplayMode(.inline)
        .onAppear { if week.isEmpty { week = store.week } }
        .task(id: week + String(fourWeeks)) { if !week.isEmpty { await load() } }
        .interactiveDismissDisabled(saving || !dirty.isEmpty)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { if dirty.isEmpty { dismiss() } else { discard = true } }.disabled(saving) } }
        .alert("Discard unsaved availability changes?", isPresented: $discard) { Button("Keep editing", role: .cancel) {}; Button("Discard", role: .destructive) { dismiss() } } message: { Text("Your saved availability will not change.") }
        .confirmationDialog("Confirm and lock this availability week?", isPresented: Binding(get: { confirmWeek != nil }, set: { if !$0 { confirmWeek = nil } }), titleVisibility: .visible) {
            Button("Confirm and lock") { if let key = confirmWeek { confirmWeek = nil; Task { await save(key, confirm: true) } } }
        }
    }
    private func value(_ week: String, _ day: String, _ shift: String) -> HOPRecord { slots[week]?.first { $0["day"].text == day && $0["shift_key"].text == shift } ?? HOPRecord(.object(["day": .string(day), "shift_key": .string(shift), "status": .string("available")])) }
    private func restoreSlots(_ key: String) {
        let source = matrices[key]?["availability"].records ?? []
        slots[key] = days.flatMap { day in ["AM", "PM"].map { shift in source.first { $0["day"].text == day && $0["shift_key"].text == shift } ?? HOPRecord(.object(["day": .string(day), "shift_key": .string(shift), "status": .string("available")])) } }; dirty.remove(key)
    }
    private func toggle(_ key: String, _ day: String, _ shift: String) {
        let current = value(key, day, shift), next = current.setting("status", .string(current["status"].text == "off" ? "available" : "off"))
        slots[key] = (slots[key] ?? []).map { $0["day"].text == day && $0["shift_key"].text == shift ? next : $0 }; dirty.insert(key)
    }
    private func load() async {
        guard !saving, dirty.isEmpty else { return }; loading = true; error = nil
        let requested = week + String(fourWeeks)
        defer { if requested == week + String(fourWeeks) { loading = false } }
        for key in weeks {
            do {
                let result = try await store.api.request("/api/availability/employee/\(store.employee?.id ?? "")", query: ["week_start": key])
                guard !Task.isCancelled && requested == week + String(fourWeeks) else { return }
                matrices[key] = result; restoreSlots(key)
            } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
        }
    }
    private func save(_ key: String, confirm: Bool) async {
        guard !saving && !store.busy else { return }; saving = true; defer { saving = false }; error = nil
        do {
            let result = try await store.api.request("/api/availability/employee/\(store.employee?.id ?? "")/\(confirm ? "confirm" : "save")", method: "POST", body: .object(["week_start": .string(key), "slots": .array((slots[key] ?? []).map(\.raw))]))
            matrices[key] = result; restoreSlots(key); HOPStyle.haptic(); store.message = confirm ? "Availability confirmed and locked." : "Availability draft saved."
        } catch { self.error = error.localizedDescription }
    }
}

struct ProfileRequestView: View {
    @EnvironmentObject private var store: HOPStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var avatar = ""
    @State private var pin = ""
    @State private var reveal = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoBusy = false
    @State private var error: String?
    @State private var loaded = false
    @State private var remotePhotoURL = ""
    private var pinValid: Bool { pin.isEmpty || ((4...8).contains(pin.count) && pin.allSatisfy(\.isNumber)) }
    private var changed: Bool { name != (store.employee?.name ?? "") || phone != (store.employee?["phone"].text ?? "") || avatar != (store.employee?["profile_image_url"].text ?? "") || !pin.isEmpty }
    var body: some View {
        Form {
            Section("Your information") { TextField("Preferred name", text: $name).textContentType(.name); TextField("Phone", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber) }
            Section("Profile photo") {
                EmployeeAvatar(url: avatar, name: name, size: 84).frame(maxWidth: .infinity).padding()
                PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("Choose photo", systemImage: "photo") }.disabled(photoBusy || store.busy)
                if photoBusy { ProgressView("Preparing photo…") }
                if !avatar.isEmpty { Button("Remove photo", role: .destructive) { avatar = "" } }
                DisclosureGroup("Use an existing photo URL") {
                    TextField("https://…", text: $remotePhotoURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Use photo URL") { if let url = URL(string: remotePhotoURL.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme == "https", url.host != nil { avatar = url.absoluteString; error = nil } else { error = "Enter a valid HTTPS image address." } }.disabled(remotePhotoURL.isEmpty)
                }
            }
            Section {
                HStack { Group { if reveal { TextField("New PIN (optional)", text: $pin) } else { SecureField("New PIN (optional)", text: $pin) } }.keyboardType(.numberPad).textContentType(.newPassword); Button { reveal.toggle() } label: { Image(systemName: reveal ? "eye.slash" : "eye").frame(width: 44, height: 44) }.accessibilityLabel(reveal ? "Hide new PIN" : "Reveal new PIN") }
                if !pinValid { Text("Use 4–8 digits for a new PIN.").foregroundStyle(.red) }
            } header: { Text("Request a new PIN") } footer: { Text("Your current PIN is never shown. Your manager must approve the replacement before it works.") }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            Section { Button("Send changes for approval") { Task { await submit() } }.disabled(store.busy || photoBusy || !pinValid || !changed || name.trimmingCharacters(in: .whitespaces).isEmpty) } footer: { Text("Your current profile stays unchanged until your manager approves. Photos are reduced in size before sending.") }
        }.navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline).scrollDismissesKeyboard(.interactively)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { pin = ""; dismiss() }.disabled(store.busy) } }
        .onAppear { if !loaded { name = store.employee?.name ?? ""; phone = store.employee?["phone"].text ?? ""; avatar = store.employee?["profile_image_url"].text ?? ""; loaded = true } }
        .task(id: selectedPhoto) { await preparePhoto() }.interactiveDismissDisabled(store.busy)
        .onDisappear { pin = "" }
    }
    private func preparePhoto() async {
        guard let selectedPhoto else { return }; photoBusy = true; defer { photoBusy = false }; error = nil
        do {
            guard let data = try await selectedPhoto.loadTransferable(type: Data.self), data.count <= 8 * 1024 * 1024, let image = UIImage(data: data) else { throw HOPAPIError(status: 0, message: "Choose a supported photo smaller than 8 MB.") }
            guard !Task.isCancelled else { return }
            let scale = min(1, 512 / max(image.size.width, image.size.height)), size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
            let resized = UIGraphicsImageRenderer(size: size, format: format).image { ctx in UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size)); image.draw(in: CGRect(origin: .zero, size: size)) }
            var quality: CGFloat = 0.85, encoded = resized.jpegData(compressionQuality: 0.85)
            while (encoded?.count ?? 0) > 220 * 1024 && quality > 0.3 { quality -= 0.1; encoded = resized.jpegData(compressionQuality: quality) }
            guard let encoded, encoded.count <= 300 * 1024 else { throw HOPAPIError(status: 0, message: "This photo is still too large. Choose a smaller photo.") }
            avatar = "data:image/jpeg;base64," + encoded.base64EncodedString()
        } catch { self.error = error.localizedDescription }
    }
    private func submit() async {
        var update: [String: JSONValue] = ["display_name": .string(name.trimmingCharacters(in: .whitespacesAndNewlines)), "phone": .string(phone), "profile_image_url": .string(avatar), "password_requested": .bool(!pin.isEmpty)]
        if !pin.isEmpty { update["pin"] = .string(pin) }
        if avatar.hasPrefix("data:image") { update["profile_image_size_kb"] = .number(Double(avatar.count * 3 / 4 / 1024)) }
        var changes: [String] = []
        if name != store.employee?.name { changes.append("Preferred name: \(name)") }
        if phone != store.employee?["phone"].text { changes.append("Phone: \(phone)") }
        if avatar != store.employee?["profile_image_url"].text { changes.append(avatar.isEmpty ? "Remove profile photo" : "Update profile photo") }
        if !pin.isEmpty { changes.append("PIN change") }
        let okay = await store.act("/api/requests", body: ["employee_id": .string(store.employee?.id ?? ""), "type": .string("general"), "note": .string("Profile update request: " + changes.joined(separator: "; ")), "payload": .object(["profile_update": .object(update)])], success: "Profile changes sent for manager approval.")
        pin = ""
        if okay { dismiss() } else { error = store.message; store.message = nil }
    }
}
