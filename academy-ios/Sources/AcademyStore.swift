import SwiftUI
import UniformTypeIdentifiers

struct ProgressDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents:data) }
}

@MainActor
final class AcademyStore: ObservableObject {
    let catalog: AcademyCatalog
    @Published private(set) var state: LearningState
    @Published var presentedSession: String?
    @Published var message: String?
    @Published var storageBlocked = false
    @Published var importCandidate: LearningState?
    private let fileURL: URL
    private let backupURL: URL
    static let encoder: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted,.sortedKeys]; e.dateEncodingStrategy = .millisecondsSince1970; return e }()
    static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .millisecondsSince1970; return d }()

    init() {
        guard let url = Bundle.main.url(forResource:"catalog",withExtension:"json"),
              let data = try? Data(contentsOf:url), let c = try? JSONDecoder().decode(AcademyCatalog.self,from:data),
              (try? c.validate()) != nil else { fatalError("Verified bundled Academy catalog is missing.") }
        catalog = c; state = LearningState(catalogVersion:c.contentVersion)
        let directory = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("HOPAcademy",isDirectory:true)
        fileURL = directory.appendingPathComponent("progress-v1.json")
        backupURL = directory.appendingPathComponent("progress-previous.json")
        do {
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            if FileManager.default.fileExists(atPath:fileURL.path) {
                do { state = try readState(fileURL) }
                catch {
                    if let recovered = try? readState(backupURL) {
                        let preserved = directory.appendingPathComponent("unreadable-\(UUID().uuidString).json")
                        try FileManager.default.copyItem(at:fileURL,to:preserved)
                        state = recovered
                        try Self.encoder.encode(recovered).write(to:fileURL,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
                        message = "Your last saved backup was recovered. The unreadable file was preserved."
                    } else { storageBlocked = true; message = "Your progress file could not be read. It has not been replaced. Import a compatible backup from Settings to recover it." }
                }
            }
            if !storageBlocked { tick() }
        } catch { storageBlocked = true; message = "Study storage is unavailable: \(error.localizedDescription)" }
        #if targetEnvironment(simulator)
        configureSnapshot()
        #endif
    }
    private func readState(_ url: URL) throws -> LearningState {
        let candidate = try Self.decoder.decode(LearningState.self,from:Data(contentsOf:url))
        try AcademyEngine.validateBackup(candidate,catalog:catalog); return candidate
    }
    func commit(_ operation: (inout LearningState) throws -> Void) {
        guard !storageBlocked else { message = "Import a compatible progress backup in Settings before studying."; return }
        do {
            var candidate = state; try operation(&candidate)
            try persist(candidate); state = candidate
        } catch { message = "Your last saved progress is safe. \(error.localizedDescription)" }
    }
    private func persist(_ candidate: LearningState) throws {
        let data = try Self.encoder.encode(candidate)
        if FileManager.default.fileExists(atPath:fileURL.path) {
            try Data(contentsOf:fileURL).write(to:backupURL,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
        }
        try data.write(to:fileURL,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
    }
    var active: StudySession? { state.sessions.last { $0.finishedAt == nil } }
    func session(_ id: String) -> StudySession? { state.sessions.first { $0.id == id } }
    func question(_ session: StudySession) -> AcademyQuestion? { try? AcademyEngine.question(session:session,catalog:catalog) }
    var chapters: [ChapterEvidence] { AcademyEngine.chapters(catalog:catalog,state:state) }
    var evidence: [ObjectiveEvidence] { catalog.objectives.map { AcademyEngine.evidence($0.id,state:state) } }
    var overall: Int? {
        let scores = evidence.compactMap(\.score)
        return scores.isEmpty ? nil : Int((Double(scores.reduce(0,+)) / Double(scores.count)).rounded())
    }
    var due: [ObjectiveEvidence] { evidence.filter(\.isDue) }
    var weak: [ObjectiveEvidence] { evidence.filter { ($0.score ?? 100) < 75 }.sorted { ($0.score ?? 0) < ($1.score ?? 0) } }
    var mocks: [ExamResult] { AcademyEngine.mockResults(state) }
    var readiness: String {
        if AcademyEngine.ready(catalog:catalog,state:state) { return "Exam ready" }
        if mocks.filter(\.unseen).last.map({ $0.score >= 32 }) == true { return "Almost ready" }
        return (overall ?? 0) >= 60 ? "Developing" : "Learning"
    }
    var accuracy: Int? {
        let recent = state.attempts.filter { $0.mode != .vocabulary }.suffix(40)
        return recent.isEmpty ? nil : Int((Double(recent.filter(\.correct).count) / Double(recent.count) * 100).rounded())
    }
    var studyMinutes: Int { Int(state.attempts.reduce(0) { $0 + $1.seconds } / 60) }
    var streakDays: Int {
        let days = Set(state.attempts.map { Calendar.current.startOfDay(for:$0.at) })
        var date = Calendar.current.startOfDay(for:Date()); var count = 0
        if !days.contains(date) { date = Calendar.current.date(byAdding:.day,value:-1,to:date)! }
        while days.contains(date) { count += 1; date = Calendar.current.date(byAdding:.day,value:-1,to:date)! }
        return count
    }
    func start(_ mode: StudyMode, chapter: Int? = nil, concept: String? = nil, extended: Bool = false, unseen: Bool = true) {
        if let active { presentedSession = active.id; return }
        var created: String?
        commit { candidate in created = try AcademyEngine.start(mode,catalog:catalog,state:&candidate,chapter:chapter,concept:concept,extended:extended,unseen:unseen) }
        if let created, state.sessions.contains(where: { $0.id == created }) { presentedSession = created }
    }
    func answer(_ session: StudySession, choice: Int, confidence: Confidence, reasoning: String) {
        commit { try AcademyEngine.answer(sessionID:session.id,questionID:session.currentID,choice:choice,confidence:confidence,reasoning:reasoning,catalog:catalog,state:&$0) }
    }
    func next(_ id: String) { commit { try AcademyEngine.next(sessionID:id,catalog:catalog,state:&$0) } }
    func go(_ id: String, _ cursor: Int) { commit { try AcademyEngine.navigate(sessionID:id,cursor:cursor,catalog:catalog,state:&$0) } }
    func finish(_ id: String) { commit { try AcademyEngine.finish(sessionID:id,catalog:catalog,state:&$0) } }
    func flag(_ id: String) {
        commit { candidate in
            guard let i = candidate.sessions.firstIndex(where: { $0.id == id }) else { return }
            let cursor = candidate.sessions[i].cursor
            if candidate.sessions[i].flags.contains(cursor) { candidate.sessions[i].flags.remove(cursor) } else { candidate.sessions[i].flags.insert(cursor) }
        }
    }
    func bookmark(_ concept: String) {
        commit { if $0.bookmarkedConcepts.contains(concept) { $0.bookmarkedConcepts.remove(concept) } else { $0.bookmarkedConcepts.insert(concept) } }
    }
    func tick() {
        guard state.sessions.contains(where: { $0.finishedAt == nil && $0.deadline.map({ $0 <= Date() }) == true }) else { return }
        commit { try AcademyEngine.expire(catalog:catalog,state:&$0) }
    }
    func suspendClock() {
        // Practice reading time is bounded; exam wall-clock deadlines continue while locked/backgrounded.
        guard let active else { return }
        commit { candidate in
            guard let i = candidate.sessions.firstIndex(where: { $0.id == active.id }) else { return }
            candidate.sessions[i].openedAt = Date()
        }
    }
    func exportDocument() -> ProgressDocument? {
        do { return ProgressDocument(data:try Self.encoder.encode(state)) }
        catch { message = error.localizedDescription; return nil }
    }
    func inspectImport(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
            guard size < 30_000_000 else { throw AcademyError.invalidBackup }
            importCandidate = try readState(url)
        } catch { message = error.localizedDescription }
    }
    func restoreImport() {
        guard let candidate = importCandidate else { return }
        do { try persist(candidate); state = candidate; storageBlocked = false; importCandidate = nil; presentedSession = nil; tick() }
        catch { message = "Restore failed. \(error.localizedDescription)" }
    }
    #if targetEnvironment(simulator)
    private func configureSnapshot() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-snapshot-reset") { state = LearningState(catalogVersion:catalog.contentVersion); try? persist(state) }
        if args.contains("-snapshot-question") { start(.practice,concept:"4.2.2") }
        if args.contains("-snapshot-exam") { start(.exam) }
    }
    #endif
}
