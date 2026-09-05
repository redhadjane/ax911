import SwiftUI
import PhotosUI
import Vision
import VisionKit
import AVFoundation

private struct ClubSession: Codable {
    let staff: HOPRecord
    let token: String
}

private enum ClubPane: String, CaseIterable, Identifiable {
    case members = "Members", redemptions = "Redemptions", activity = "Activity"
    var id: String { rawValue }
}

@MainActor private final class ClubStore: ObservableObject {
    @Published var staff: HOPRecord?
    @Published var pane: ClubPane = .members
    @Published var query = ""
    @Published var status = "all"
    @Published var members: [HOPRecord] = []
    @Published var member: HOPRecord?
    @Published var loyalty: JSONValue = .null
    @Published var redemptions: [HOPRecord] = []
    @Published var selectedRedemption: HOPRecord?
    @Published var activity: [HOPRecord] = []
    @Published var busy = false
    @Published var error: String?
    @Published var notice: String?
    @Published var searched = false
    private var api: HOPAPI?
    private var token = ""
    private var restored = false
    private var generation: UInt64 = 0
    private var employeeSession: Data?
    private let prefix = "/api/hopclub/v2/staff"

    func connect(_ api: HOPAPI) async {
        self.api = api
        guard !restored else { return }
        restored = true
        employeeSession = SessionKeychain.read()
        guard let data = SessionKeychain.read(account: "club"),
              let session = try? JSONDecoder().decode(ClubSession.self, from: data),
              !session.token.isEmpty else { return }
        staff = session.staff
        token = session.token
        // This authenticated read verifies saved staff access before any action.
        await refresh()
    }

    func login(name: String, pin: String) async {
        guard !busy, let api else { return }
        let operation = generation
        busy = true; error = nil; notice = nil
        defer { if generation == operation { busy = false } }
        do {
            try verify(operation)
            let payload = try await api.request(prefix + "/login", method: "POST", body: .object([
                "name": .string(name.trimmingCharacters(in: .whitespacesAndNewlines)), "pin": .string(pin)
            ]), tokenOverride: "")
            // A dismissed screen or root logout must never resurrect this login.
            try verify(operation)
            let person = HOPRecord(payload["employee"])
            let credential = payload["access_token"].text
            guard !person.id.isEmpty, !credential.isEmpty else {
                throw HOPAPIError(status: 401, message: "HOP did not return a valid staff session.")
            }
            try SessionKeychain.write(JSONEncoder().encode(ClubSession(staff: person, token: credential)), account: "club")
            token = credential; staff = person
            redemptions = try await queueRecords()
            HOPStyle.haptic()
        } catch { if generation == operation { report(error) } }
    }

    func suspend() {
        // Invalidate results, but retain the already established Keychain session.
        generation &+= 1
        busy = false
    }

    func signOut() {
        suspend()
        SessionKeychain.clear(account: "club")
        staff = nil; token = ""; members = []; member = nil; loyalty = .null
        redemptions = []; selectedRedemption = nil; activity = []; searched = false
        query = ""; notice = nil; error = nil
    }

    private func verify(_ operation: UInt64, credential: String? = nil) throws {
        try Task.checkCancellation()
        guard generation == operation, credential == nil || token == credential else { throw CancellationError() }
        // Check the parent session synchronously, not only SwiftUI's eventual
        // onDisappear/onChange delivery. A logout or re-login invalidates this
        // owner even if a staff HTTP response wins the next UI callback race.
        guard let employeeSession, SessionKeychain.read() == employeeSession else { throw CancellationError() }
    }

    private func report(_ caught: Error) {
        guard !(caught is CancellationError) else { return }
        if let failure = caught as? HOPAPIError, failure.status == 401 {
            signOut()
            error = "Your HOP Club staff session expired. Sign in with your employee PIN again."
        } else { error = caught.localizedDescription }
    }

    private func reportMutation(_ caught: Error) {
        guard !(caught is CancellationError) else { return }
        if caught is URLError {
            error = "The connection ended before HOP confirmed the result. Refresh this member or redemption before trying again so the same action is not recorded twice."
        } else { report(caught) }
    }

    private func request(_ suffix: String, method: String = "GET", query: [String: String] = [:], body: JSONValue? = nil) async throws -> JSONValue {
        guard let api, !token.isEmpty else { throw HOPAPIError(status: 401, message: "Sign in to HOP Club staff first.") }
        let operation = generation
        let credential = token
        do {
            try verify(operation, credential: credential)
            let result = try await api.request(prefix + suffix, method: method, query: query, body: body, tokenOverride: credential)
            try verify(operation, credential: credential)
            return result
        } catch {
            // A late 401 from an older session cannot sign out a newer session.
            try verify(operation, credential: credential)
            throw error
        }
    }

    private func queueRecords() async throws -> [HOPRecord] {
        let payload = try await request("/redemptions", query: ["status": status, "q": pane == .redemptions ? query : ""])
        if !payload["staff"]["id"].text.isEmpty { staff = HOPRecord(payload["staff"]) }
        return payload["redemptions"].records
    }

    private func memberRecord(_ params: [String: String]) async throws {
        let payload = try await request("/member", query: params)
        let person = HOPRecord(payload["customer"])
        guard !person.id.isEmpty else { throw HOPAPIError(status: 404, message: "This member could not be found.") }
        member = person; loyalty = payload["loyalty"]
    }

    func refresh() async {
        guard !busy, staff != nil else { return }
        let operation = generation
        busy = true; error = nil
        defer { if generation == operation { busy = false } }
        do {
            switch pane {
            case .members:
                if let member { try await memberRecord(["customer_id": member.id]) }
                else { redemptions = try await queueRecords() }
            case .redemptions: redemptions = try await queueRecords()
            case .activity: activity = try await request("/activity")["activity"].records
            }
        } catch { report(error) }
    }

    func search() async {
        guard !busy else { return }
        let operation = generation
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if pane == .members && value.isEmpty { error = "Enter a member name, phone, or member code."; return }
        busy = true; error = nil; notice = nil
        defer { if generation == operation { busy = false } }
        do {
            if pane == .redemptions { redemptions = try await queueRecords() }
            else {
                let result = try await request("/members", query: ["q": value])
                members = result["customers"].records; searched = true
            }
        } catch { report(error) }
    }

    func selectMember(_ id: String) async {
        guard !busy else { return }; busy = true; error = nil; notice = nil
        let operation = generation
        defer { if generation == operation { busy = false } }
        do { try await memberRecord(["customer_id": id]); HOPStyle.haptic() }
        catch { report(error) }
    }

    func clearMember() { member = nil; loyalty = .null; members = []; query = ""; searched = false; notice = nil }

    func useScan(_ raw: String) async {
        guard !busy else { return }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = URLComponents(string: value)
        let items = components?.queryItems ?? []
        let redemption = items.first { $0.name == "redemption" }?.value
        let memberToken = items.first { $0.name == "member" }?.value
        if let redemption, !redemption.isEmpty {
            pane = .redemptions; query = redemption
            await search()
            return
        }
        if let memberToken, !memberToken.isEmpty {
            let operation = generation
            busy = true; error = nil; notice = nil
            defer { if generation == operation { busy = false } }
            do { try await memberRecord(["member": memberToken]); pane = .members; HOPStyle.haptic() }
            catch { report(error) }
            return
        }
        // Short redemption/member IDs can be searched without opening arbitrary URLs.
        if components?.scheme != nil {
            error = "This QR does not contain a HOP member or redemption code. Use member search instead."
        } else {
            query = value
            await search()
        }
    }

    func purchase(total: Double, receipt: String) async -> Bool {
        guard !busy, let member, total.isFinite, total > 0 else { return false }
        let operation = generation
        busy = true; error = nil; notice = nil
        defer { if generation == operation { busy = false } }
        do {
            let result = try await request("/purchases", method: "POST", body: .object([
                "customer_id": .string(member.id), "total": .number(total), "receipt_note": .string(receipt)
            ]))
            let points = result["purchase"]["points_earned"].text
            notice = points.isEmpty ? "Purchase recorded." : "Purchase recorded. \(points) points added."
            HOPStyle.haptic()
            do { try await memberRecord(["customer_id": member.id]) }
            catch is CancellationError { return false }
            catch { self.error = "The purchase was saved, but the member balance could not refresh. Refresh before recording another ticket." }
            return true
        } catch { reportMutation(error); return false }
    }

    func redeem(_ reward: HOPRecord) async {
        guard !busy, let member, reward["unlocked"].flag, !reward.id.isEmpty else { return }
        let operation = generation
        busy = true; error = nil; notice = nil
        defer { if generation == operation { busy = false } }
        do {
            _ = try await request("/redeem", method: "POST", body: .object([
                "customer_id": .string(member.id), "reward_rule_id": .string(reward.id),
                "note": .string("Redeemed by staff in HOP Employee for iOS")
            ]))
            notice = "\(reward.title) redeemed for \(member.name)."; HOPStyle.haptic()
            do { try await memberRecord(["customer_id": member.id]) }
            catch is CancellationError { return }
            catch { self.error = "The reward was redeemed, but the balance could not refresh. Refresh before redeeming again." }
        } catch { reportMutation(error) }
    }

    func selectRedemption(_ id: String) async {
        guard !busy else { return }; busy = true; error = nil
        let operation = generation
        defer { if generation == operation { busy = false } }
        do { selectedRedemption = HOPRecord(try await request("/redemptions/\(id)")["redemption"]) }
        catch { report(error) }
    }

    func mutateRedemption(_ action: String) async {
        guard !busy, let selectedRedemption, ["confirm", "retry-print", "cancel"].contains(action) else { return }
        let operation = generation
        busy = true; error = nil; notice = nil
        defer { if generation == operation { busy = false } }
        do {
            let result = try await request("/redemptions/\(selectedRedemption.id)/\(action)", method: "POST", body: .object([:]))
            let changed = result["redemption"].fields.isEmpty ? result["request"] : result["redemption"]
            if !changed["id"].text.isEmpty { self.selectedRedemption = HOPRecord(changed) }
            redemptionOutcome(action: action, result: result, changed: changed)
            HOPStyle.haptic()
            do {
                self.selectedRedemption = HOPRecord(try await request("/redemptions/\(selectedRedemption.id)")["redemption"])
                redemptions = try await queueRecords()
            } catch is CancellationError { return }
            catch { self.error = "The action was saved. Refresh to check the latest ticket status before retrying." }
        } catch { reportMutation(error) }
    }

    private func redemptionOutcome(action: String, result: JSONValue, changed: JSONValue) {
        let state = changed["status"].text
        if state == "print_failed" || changed["print_status"].text == "failed" {
            notice = nil
            error = "The reward is confirmed, but one or more ticket copies failed. Review the ticket details below and retry only the failed copies. No further points or visits are deducted."
        } else if action == "retry-print", result["retried"] == .bool(false) {
            notice = state == "completed" ? "Tickets are already completed. No copies were requeued."
                : "Tickets are already in progress. No duplicate copies were queued."
        } else if state == "completed" {
            notice = "Reward confirmed. Both ticket copies are completed."
        } else if state == "printing" {
            notice = action == "retry-print" ? "Failed ticket copies requeued without another deduction."
                : "Reward confirmed. Kitchen and register tickets queued."
        } else if state == "cancelled" {
            notice = "Pending redemption cancelled."
        } else {
            notice = "HOP accepted the action. Review the current redemption and ticket status below."
        }
    }
}

@MainActor struct ClubView: View {
    @EnvironmentObject private var store: HOPStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var club = ClubStore()
    @State private var loginName = ""
    @State private var pin = ""
    @State private var revealPIN = false
    @State private var scanner = false
    @State private var purchaseSheet = false
    @State private var photo: PhotosPickerItem?
    @State private var readingPhoto = false
    @State private var rewardConfirmation: HOPRecord?
    @State private var redemptionRoute: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if club.staff == nil { loginPanel }
                else { workspace }
            }.padding(20).frame(maxWidth: 760)
        }
        .background(HOPStyle.background)
        .navigationTitle("HOP Club")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.disabled(club.busy || readingPhoto)
            }
        }
        .interactiveDismissDisabled(club.busy || readingPhoto)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await club.refresh() }
        .task {
            loginName = store.employee?.name ?? ""
            await club.connect(store.api)
        }
        .onDisappear {
            // Internal navigation transfers lifecycle ownership to the detail view.
            if redemptionRoute == nil { club.suspend() }
        }
        .onChange(of: store.employee?.id) { old, current in
            if old != current { club.signOut() }
        }
        .navigationDestination(item: $redemptionRoute) { id in
            ClubRedemptionView(club: club, redemptionID: id)
        }
        .onChange(of: club.pane) { _, _ in
            club.error = nil
            Task { await club.refresh() }
        }
        .onChange(of: photo) { _, chosen in
            guard let chosen else { return }
            Task { await readPhoto(chosen); photo = nil }
        }
        .sheet(isPresented: $scanner) {
            NavigationStack {
                ClubQRScanner { value in
                    scanner = false
                    Task { await club.useScan(value) }
                } failed: { detail in scanner = false; club.error = detail }
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Scan HOP QR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { scanner = false } } }
            }
        }
        .sheet(isPresented: $purchaseSheet) {
            NavigationStack { ClubPurchaseView(club: club) }
        }
        .alert("Redeem this reward?", isPresented: Binding(get: { rewardConfirmation != nil }, set: { if !$0 { rewardConfirmation = nil } })) {
            Button("Cancel", role: .cancel) { rewardConfirmation = nil }
            Button("Redeem") {
                if let reward = rewardConfirmation { Task { await club.redeem(reward) } }
                rewardConfirmation = nil
            }
        } message: {
            Text("\(rewardConfirmation?.title ?? "Reward") for \(club.member?.name ?? "this member"). HOP will verify eligibility before applying it.")
        }
    }

    private var loginPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image("HOPLogo").resizable().scaledToFit().frame(width: 72, height: 72)
            Text("A little extra for our regulars.").font(.largeTitle.bold())
            Text("Sign in to staff loyalty to find members, record tickets, and manage reward redemptions.").foregroundStyle(.secondary)
            HOPCard {
                TextField("Employee name or phone", text: $loginName).textContentType(.username).textInputAutocapitalization(.words).autocorrectionDisabled()
                Divider()
                HStack {
                    Group {
                        if revealPIN { TextField("Employee PIN", text: $pin) }
                        else { SecureField("Employee PIN", text: $pin) }
                    }.keyboardType(.numberPad).textContentType(.password)
                    Button { revealPIN.toggle() } label: {
                        Image(systemName: revealPIN ? "eye.slash" : "eye").frame(width: 44, height: 44)
                    }.accessibilityLabel(revealPIN ? "Hide PIN" : "Reveal PIN")
                }
                feedback
                Button {
                    Task { let credential = pin; pin = ""; await club.login(name: loginName, pin: credential) }
                } label: {
                    HStack { if club.busy { ProgressView().tint(.white) }; Text(club.busy ? "Signing in…" : "Open staff loyalty").frame(maxWidth: .infinity) }
                }.buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(club.busy || loginName.trimmingCharacters(in: .whitespaces).isEmpty || pin.isEmpty)
            }
            Text("Your existing employee PIN verifies staff access. This separate staff session is stored securely on this iPhone.").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var workspace: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Staff loyalty").font(.title2.bold())
                    Text("Signed in as \(club.staff?.name ?? "")").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Refresh", systemImage: "arrow.clockwise") { Task { await club.refresh() } }
                    Button(role: .destructive) { club.signOut() } label: {
                        Label("Sign out of staff loyalty", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: { Image(systemName: "ellipsis.circle").font(.title2).frame(width: 44, height: 44) }
                .disabled(club.busy).accessibilityLabel("Staff loyalty actions")
            }
            Picker("Staff workspace", selection: Binding(get: { club.pane }, set: { club.query = ""; club.pane = $0 })) {
                ForEach(ClubPane.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).disabled(club.busy)
            feedback
            if club.busy || readingPhoto { ProgressView(readingPhoto ? "Reading QR photo…" : "Checking HOP…").frame(maxWidth: .infinity).accessibilityAddTraits(.updatesFrequently) }
            switch club.pane {
            case .members:
                if let member = club.member { memberPanel(member) }
                else { lookupPanel; memberResults }
            case .redemptions:
                lookupPanel
                redemptionQueue
            case .activity: activityPanel
            }
        }
    }

    @ViewBuilder private var feedback: some View {
        if let error = club.error {
            VStack(alignment: .leading, spacing: 6) {
                Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red)
                if club.staff != nil { Button("Try refresh") { Task { await club.refresh() } }.disabled(club.busy) }
            }.font(.subheadline).accessibilityElement(children: .combine)
        }
        if let notice = club.notice { Label(notice, systemImage: "checkmark.circle.fill").foregroundStyle(HOPStyle.green).font(.subheadline) }
    }

    private var lookupPanel: some View {
        HOPCard {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(club.pane == .members ? "Name, phone, or member code" : "Member or redemption ID", text: $club.query)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
                    .onSubmit { Task { await club.search() } }
                Button("Search") { Task { await club.search() } }.fontWeight(.semibold)
            }
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { scanButton; photoButton }
                VStack(alignment: .leading, spacing: 12) { scanButton; photoButton }
            }
        }.disabled(club.busy || readingPhoto)
    }

    private var scanButton: some View {
        Button { Task { await openScanner() } } label: { Label("Scan QR", systemImage: "qrcode.viewfinder").frame(minHeight: 44) }
    }
    private var photoButton: some View {
        PhotosPicker(selection: $photo, matching: .images) { Label("Choose QR photo", systemImage: "photo").frame(minHeight: 44) }
    }

    private var memberResults: some View {
        VStack(spacing: 12) {
            if club.members.isEmpty {
                HOPEmpty(title: club.searched ? "No member found" : "Find a HOP member", detail: club.searched ? "Try their phone number or scan the QR on their member card." : "Scan a member card or search to see their visits and available rewards.", icon: "person.crop.rectangle")
            }
            ForEach(club.members) { person in
                Button { Task { await club.selectMember(person.id) } } label: {
                    HOPCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(person.name).font(.headline)
                                Text(person.first("display_phone", "phone", "member_code")).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                }.buttonStyle(.plain).disabled(club.busy)
            }
        }
    }

    private func memberPanel(_ member: HOPRecord) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Button { club.clearMember() } label: { Label("Find another member", systemImage: "arrow.left") }.disabled(club.busy)
            HOPCard {
                Text(member.name).font(.title.bold())
                Text(member.first("member_code", "display_phone", "phone")).font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 32) {
                    stat("Points", club.loyalty["points_balance"].text)
                    stat("Visits", club.loyalty["purchase_count"].text)
                }.padding(.vertical, 8)
                if !club.loyalty["visit_goal"].text.isEmpty {
                    let goal = max(1, club.loyalty["visit_goal"].number)
                    ProgressView(value: min(goal, max(0, club.loyalty["visit_progress"].number)), total: goal)
                    Text("\(club.loyalty["visits_until_next_reward"].text) visits until the next visit reward").font(.footnote).foregroundStyle(.secondary)
                }
                Button { purchaseSheet = true } label: { Label("Record a purchase", systemImage: "plus.circle.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(club.busy)
            }
            HOPSection(title: "Rewards") {
                let rewards = club.loyalty["rewards"].records
                if rewards.isEmpty { HOPEmpty(title: "No rewards available", detail: "HOP has not returned any rewards for this member.", icon: "gift") }
                ForEach(rewards) { reward in
                    Button { rewardConfirmation = reward } label: {
                        ClubRewardRow(reward: reward)
                    }.buttonStyle(.plain).disabled(club.busy || !reward["unlocked"].flag)
                    .accessibilityHint(reward["unlocked"].flag ? "Review and redeem this reward" : "This reward is not yet unlocked")
                }
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value.isEmpty ? "—" : value).font(.title.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var redemptionQueue: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Redemption status", selection: $club.status) {
                Text("All").tag("all"); Text("Pending").tag("pending")
                Text("Print issues").tag("print_failed"); Text("Completed").tag("completed")
            }.pickerStyle(.menu).disabled(club.busy)
                .onChange(of: club.status) { _, _ in Task { await club.refresh() } }
            if club.redemptions.isEmpty && !club.busy {
                HOPEmpty(title: "No redemptions found", detail: "Try a different status, member, or redemption ID.", icon: "gift")
            }
            ForEach(club.redemptions) { redemption in
                Button { redemptionRoute = redemption.id } label: {
                    HOPCard {
                        HStack { Text(redemption["short_id"].text).font(.caption.monospaced()); Spacer(); HOPStatus(value: redemption.status) }
                        Text(redemption["customer_name"].text).font(.headline)
                        Text(redemption["reward_title"].text).font(.subheadline).foregroundStyle(.secondary)
                        Text(clubDate(redemption["created_at"].text)).font(.caption).foregroundStyle(.secondary)
                    }
                }.buttonStyle(.plain).disabled(club.busy)
            }
        }
    }

    private var activityPanel: some View {
        HOPSection(title: "Recent staff activity") {
            if club.activity.isEmpty && !club.busy { HOPEmpty(title: "No activity yet", detail: "Recorded purchases and reward redemptions will appear here.", icon: "clock") }
            ForEach(Array(club.activity.enumerated()), id: \.offset) { _, item in
                HOPCard {
                    Label(item["action"].text == "reward" ? "Reward redeemed" : clubMoney(item["amount"].number) + " purchase", systemImage: item["action"].text == "reward" ? "gift" : "receipt")
                        .font(.headline)
                    Text(item["customer_name"].text).font(.subheadline)
                    Text(clubDate(item["created_at"].text)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func openScanner() async {
        guard DataScannerViewController.isSupported else { club.error = "Live scanning is unavailable on this device. Choose a QR photo or use search."; return }
        let access = AVCaptureDevice.authorizationStatus(for: .video)
        let allowed = access == .authorized ? true : access == .notDetermined ? await AVCaptureDevice.requestAccess(for: .video) : false
        guard allowed else { club.error = "Camera access is off. Enable it for HOP Employee in iPhone Settings, or choose a QR photo."; return }
        guard DataScannerViewController.isAvailable else { club.error = "The camera is currently unavailable. Try again, choose a QR photo, or search."; return }
        scanner = true
    }

    private func readPhoto(_ item: PhotosPickerItem) async {
        guard !readingPhoto, !club.busy else { return }
        readingPhoto = true; club.error = nil
        defer { readingPhoto = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw HOPAPIError(status: 0, message: "That photo could not be opened.") }
            let result = try await ClubPhotoDecoder.decode(data)
            await club.useScan(result)
        } catch { club.error = error.localizedDescription }
    }
}

private struct ClubRewardRow: View {
    let reward: HOPRecord
    var body: some View {
        HOPCard {
            HStack(spacing: 14) {
                ClubRewardImage(reward: reward)
                    .frame(width: 84, height: 64).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    Text(reward.title).font(.headline)
                    Text(reward["unlocked"].flag ? "Ready to redeem" : "Not unlocked yet").font(.subheadline).foregroundStyle(reward["unlocked"].flag ? HOPStyle.green : .secondary)
                    if !reward["description"].text.isEmpty { Text(reward["description"].text).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
                if reward["unlocked"].flag { Image(systemName: "chevron.right").foregroundStyle(.secondary) }
            }
        }
    }
}

private struct ClubRewardImage: View {
    let reward: HOPRecord
    private var sources: [URL] {
        [reward["image_url"].text, reward["reward_image_url"].text].compactMap(clubImageURL)
    }
    private var artwork: ClubRewardArtwork? { sources.first.flatMap(ClubRewardArtwork.init(url:)) }
    private var raster: URL? { sources.first { $0.pathExtension.lowercased() != "svg" } }

    var body: some View {
        Group {
            if let artwork {
                artwork.accessibilityLabel("\(reward.title) reward illustration")
            } else if let raster {
                AsyncImage(url: raster) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill().accessibilityLabel(reward.title)
                    case .empty: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    default: unavailable("Image unavailable")
                    }
                }
            } else {
                unavailable(sources.isEmpty ? "No image" : "SVG unavailable")
            }
        }.background(HOPStyle.green.opacity(0.05))
    }

    private func unavailable(_ title: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "photo").font(.title3)
            Text(title).font(.caption2).multilineTextAlignment(.center)
        }.foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Native vector rendition of the five checked-in /public/assets/rewards/*.svg
/// assets. Their source geometry is identical; only palette and caption vary.
/// This is not a general SVG engine: custom SVGs require a server-provided raster
/// alternative and otherwise show an explicit unavailable state. No web view,
/// remote script, or unsupported UIImage SVG decoding is used.
private struct ClubRewardArtwork: View {
    let caption: String
    let accent: Color
    let background: Color

    init?(url: URL) {
        guard url.host?.lowercased() == HOPAPI.baseURL.host?.lowercased(),
              url.deletingLastPathComponent().path == "/public/assets/rewards" else { return nil }
        let palette: (String, UInt32, UInt32)
        switch url.lastPathComponent {
        case "catering-vip.svg": palette = ("VIP catering", 0x8b5a0e, 0xfff2d8)
        case "dessert-pizza.svg": palette = ("Dessert pizza", 0xb81922, 0xfff1ef)
        case "garlic-knots.svg": palette = ("Garlic knots", 0x0f5b4c, 0xe8f3ef)
        case "large-pizza.svg": palette = ("Large pizza", 0xd89a2b, 0xfff2d8)
        case "pasta-tray.svg": palette = ("Catering tray", 0x246b8f, 0xe8f1ff)
        default: return nil
        }
        caption = palette.0; accent = Self.color(palette.1); background = Self.color(palette.2)
    }

    var body: some View {
        Canvas { original, size in
            var context = original
            let scale = min(size.width / 600, size.height / 420)
            context.translateBy(x: (size.width - 600 * scale) / 2, y: (size.height - 420 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            let bounds = CGRect(x: 0, y: 0, width: 600, height: 420)
            let backgroundPath = RoundedRectangle(cornerRadius: 54).path(in: bounds)
            context.clip(to: backgroundPath)
            context.fill(backgroundPath, with: .linearGradient(Gradient(colors: [background, .white]), startPoint: .zero, endPoint: CGPoint(x: 600, y: 420)))
            circle(&context, x: 485, y: 55, radius: 140, color: accent.opacity(0.10))
            circle(&context, x: 100, y: 352, radius: 95, color: accent.opacity(0.08))
            var plate = context
            plate.addFilter(.shadow(color: Self.color(0x14231f).opacity(0.15), radius: 16, x: 0, y: 18))
            plate.drawLayer { layer in
                layer.fill(RoundedRectangle(cornerRadius: 42).path(in: CGRect(x: 96, y: 86, width: 408, height: 240)), with: .color(Self.color(0xfffdf8)))
                var crust = Path()
                crust.move(to: CGPoint(x: 154, y: 245))
                crust.addCurve(to: CGPoint(x: 452, y: 245), control1: CGPoint(x: 230, y: 95), control2: CGPoint(x: 370, y: 88))
                crust.closeSubpath()
                layer.fill(crust, with: .color(accent.opacity(0.92)))
                var cheese = Path()
                cheese.move(to: CGPoint(x: 190, y: 233))
                cheese.addCurve(to: CGPoint(x: 416, y: 233), control1: CGPoint(x: 252, y: 128), control2: CGPoint(x: 356, y: 123))
                cheese.closeSubpath()
                layer.fill(cheese, with: .color(Self.color(0xfff7df)))
                circle(&layer, x: 265, y: 185, radius: 18, color: Self.color(0xb81922).opacity(0.9))
                circle(&layer, x: 335, y: 174, radius: 16, color: Self.color(0x0f5b4c).opacity(0.88))
                circle(&layer, x: 310, y: 221, radius: 14, color: Self.color(0xd89a2b).opacity(0.85))
            }
            context.draw(Text(caption).font(.system(size: 36, weight: .black)).foregroundColor(Self.color(0x14231f)), at: CGPoint(x: 300, y: 347), anchor: .center)
        }
    }

    private func circle(_ context: inout GraphicsContext, x: CGFloat, y: CGFloat, radius: CGFloat, color: Color) {
        context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
    }

    private static func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
}

private struct ClubPurchaseView: View {
    @ObservedObject var club: ClubStore
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var receipt = ""
    @State private var confirming = false
    private var total: Double { Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    var body: some View {
        Form {
            Section {
                Text(club.member?.name ?? "").font(.title2.bold())
                Text("Use the ticket total. The server calculates the earned points and records the visit.").font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Purchase") {
                TextField("Ticket total ($)", text: $amount).keyboardType(.decimalPad)
                TextField("Ticket number or note (optional)", text: $receipt)
            }
            if let error = club.error { Section { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red) } }
            Section {
                Button { confirming = true } label: {
                    HStack { if club.busy { ProgressView() }; Text(club.busy ? "Recording…" : "Review purchase").frame(maxWidth: .infinity) }
                }.disabled(club.busy || !total.isFinite || total <= 0)
            }
        }
        .navigationTitle("Record purchase")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(club.busy) } }
        .interactiveDismissDisabled(club.busy)
        .confirmationDialog("Record \(clubMoney(total)) for \(club.member?.name ?? "this member")?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Confirm purchase") { Task { if await club.purchase(total: total, receipt: receipt) { dismiss() } } }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct ClubRedemptionView: View {
    @EnvironmentObject private var store: HOPStore
    @ObservedObject var club: ClubStore
    let redemptionID: String
    @State private var action: String?
    private var record: HOPRecord? { club.selectedRedemption?.id == redemptionID ? club.selectedRedemption : nil }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let error = club.error { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
                if let notice = club.notice { Label(notice, systemImage: "checkmark.circle.fill").foregroundStyle(HOPStyle.green) }
                if club.busy { ProgressView("Checking redemption…").frame(maxWidth: .infinity) }
                if let record { detail(record) }
                else if !club.busy {
                    HOPEmpty(title: "Redemption unavailable", detail: "Refresh to retry, or return to the redemption queue.", icon: "gift")
                }
                Button("Refresh status", systemImage: "arrow.clockwise") { Task { await club.selectRedemption(redemptionID) } }.disabled(club.busy || club.staff == nil)
            }.padding(20)
        }.background(HOPStyle.background)
        .navigationTitle("Redemption")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(club.busy)
        .task(id: redemptionID) { await club.selectRedemption(redemptionID) }
        .onDisappear { club.suspend() }
        .onChange(of: store.employee?.id) { old, current in
            if old != current { club.signOut() }
        }
        .interactiveDismissDisabled(club.busy)
        .confirmationDialog(confirmationTitle, isPresented: Binding(get: { action != nil }, set: { if !$0 { action = nil } }), titleVisibility: .visible) {
            Button(action == "cancel" ? "Cancel redemption" : action == "retry-print" ? "Retry failed tickets" : "Confirm & print 2 copies", role: action == "cancel" ? .destructive : nil) {
                if let action { Task { await club.mutateRedemption(action) } }
                action = nil
            }
            Button("Keep reviewing", role: .cancel) { action = nil }
        }
    }

    private var confirmationTitle: String {
        switch action {
        case "confirm": return "Confirm this reward? HOP rechecks eligibility, consumes it once, and queues kitchen and register tickets."
        case "retry-print": return "Retry only the failed ticket copies? The reward will not be deducted again."
        default: return "Cancel this pending request? No points or visits will be consumed."
        }
    }

    private func detail(_ record: HOPRecord) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HOPCard {
                HStack { Text(record["short_id"].text).font(.caption.monospaced()); Spacer(); HOPStatus(value: record.status) }
                Text(record["customer_name"].text).font(.title2.bold())
                Text([record["phone_masked"].text, record["member_id"].text].filter { !$0.isEmpty }.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                Divider()
                Text(record.first("reward_item_name", "reward_title")).font(.headline)
                info("Current points", record["points_balance"].text)
                info("Requirement", record["reward_type"].text == "visit_milestone" ? "\(record["visits_required"].text) visits" : "\(record["points_required"].text) points")
                info("Expires", clubDate(record["expires_at"].text))
                info("Confirmed by", record["confirmed_by_employee_name"].text)
                info("Confirmed", clubDate(record["confirmed_at"].text))
            }
            HOPSection(title: "Ticket copies") {
                HOPStatus(value: record["print_status"].text)
                let jobs = record["print_jobs"].records
                if jobs.isEmpty { Text("No ticket copies have been queued.").foregroundStyle(.secondary) }
                ForEach(Array(jobs.enumerated()), id: \.offset) { _, job in
                    HOPCard {
                        HStack { Text("\(job["copy_type"].text.capitalized) copy").font(.headline); Spacer(); HOPStatus(value: job.status) }
                        Text("Attempt \(job["attempt_number"].text)").font(.caption).foregroundStyle(.secondary)
                        if !job["last_error"].text.isEmpty { Text(job["last_error"].text).font(.subheadline).foregroundStyle(.red) }
                    }
                }
                if !record["last_error"].text.isEmpty { Text(record["last_error"].text).font(.subheadline).foregroundStyle(.red) }
            }
            VStack(spacing: 12) {
                if record.status == "pending_staff_confirmation" {
                    Button { action = "confirm" } label: { Label("Confirm & print 2 copies", systemImage: "printer").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                    Button("Cancel pending redemption", role: .destructive) { action = "cancel" }.buttonStyle(.bordered)
                }
                if record.status == "print_failed" || record["print_status"].text == "failed" {
                    Button { action = "retry-print" } label: { Label("Retry failed print", systemImage: "arrow.clockwise").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                }
            }.controlSize(.large).disabled(club.busy || club.staff == nil)
            HOPSection(title: "Audit history") {
                let history = record["audit"].records
                if history.isEmpty { Text("No audit entries yet.").foregroundStyle(.secondary) }
                ForEach(Array(history.enumerated()), id: \.offset) { _, entry in
                    HOPCard {
                        Text(entry["action"].text.replacingOccurrences(of: "_", with: " ").capitalized).font(.headline)
                        Text(entry["employee_name"].text.isEmpty ? "System" : entry["employee_name"].text).font(.subheadline)
                        let transition = [entry["from_status"].text, entry["to_status"].text].filter { !$0.isEmpty }.joined(separator: " → ")
                        if !transition.isEmpty { Text(transition.replacingOccurrences(of: "_", with: " ")).font(.caption).foregroundStyle(.secondary) }
                        Text(clubDate(entry["created_at"].text)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func info(_ title: String, _ value: String) -> some View {
        LabeledContent(title) { Text(value.isEmpty ? "—" : value).multilineTextAlignment(.trailing) }.font(.subheadline)
    }
}

private func clubMoney(_ value: Double) -> String {
    value.formatted(.currency(code: "USD"))
}

private func clubDate(_ value: String) -> String {
    guard !value.isEmpty else { return "—" }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    guard let date else { return value }
    let display = DateFormatter(); display.locale = .autoupdatingCurrent
    display.timeZone = HOPCalendar.zone; display.dateStyle = .medium; display.timeStyle = .short
    return display.string(from: date)
}

private func clubImageURL(_ path: String) -> URL? {
    guard !path.isEmpty else { return nil }
    if path.hasPrefix("/") { return URL(string: path, relativeTo: HOPAPI.baseURL)?.absoluteURL }
    guard let url = URL(string: path), url.scheme?.lowercased() == "https" else { return nil }
    return url
}

private enum ClubPhotoDecoder {
    static func decode(_ data: Data) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNDetectBarcodesRequest()
            request.symbologies = [.qr]
            try VNImageRequestHandler(data: data, options: [:]).perform([request])
            guard let value = request.results?.compactMap({ $0.payloadStringValue }).first else {
                throw HOPAPIError(status: 0, message: "No readable QR was found in that photo. Try a clearer image or use search.")
            }
            return value
        }.value
    }
}

private struct ClubQRScanner: UIViewControllerRepresentable {
    let found: (String) -> Void
    let failed: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(found: found, failed: failed) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced,
            recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true, isGuidanceEnabled: true, isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        do { try controller.startScanning() }
        catch { DispatchQueue.main.async { failed("The QR camera could not start. Choose a QR photo or use search.") } }
        return controller
    }
    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}
    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) { controller.stopScanning() }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let found: (String) -> Void
        let failed: (String) -> Void
        private var delivered = false
        init(found: @escaping (String) -> Void, failed: @escaping (String) -> Void) { self.found = found; self.failed = failed }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !delivered else { return }
            for item in addedItems {
                if case .barcode(let code) = item, let value = code.payloadStringValue {
                    delivered = true; dataScanner.stopScanning(); found(value); return
                }
            }
        }
        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            guard !delivered else { return }; delivered = true
            dataScanner.stopScanning()
            failed("The camera is unavailable. Choose a QR photo or search for the member.")
        }
    }
}
