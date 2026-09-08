import Foundation

struct AcademyCatalog: Codable {
    var certification: String
    var syllabus: String
    var verified: String
    var contentVersion: String
    var objectives: [LearningObjective]
    var concepts: [LearningConcept]
    var questions: [AcademyQuestion]
    var sources: [OfficialSource]
    var keywords: [String: String]
    func question(_ id: String) -> AcademyQuestion? { questions.first { $0.id == id } }
    func concept(_ id: String) -> LearningConcept? { concepts.first { $0.id == id } }
    func validate() throws {
        guard objectives.count == 64, Set(questions.map(\.id)).count == questions.count else { throw AcademyError.invalidCatalog }
        for q in questions {
            guard let lo = objectives.first(where: { $0.id == q.objective }), q.options.count == 4,
                  Set(q.options).count == 4, (0..<4).contains(q.answer), q.level == lo.level,
                  q.chapter == lo.chapter, concept(q.concept) != nil, q.original else { throw AcademyError.invalidCatalog }
        }
        for lo in objectives where questions.filter({ $0.objective == lo.id }).count < 2 { throw AcademyError.invalidCatalog }
    }
}
struct LearningObjective: Codable, Identifiable {
    var id: String; var level: String; var title: String; var chapter: Int; var section: String; var page: Int; var source: String
}
struct LearningConcept: Codable, Identifiable {
    var id: String; var term: String; var intuitive: String; var lesson: String; var objective: String; var source: String; var section: String
}
struct AcademyQuestion: Codable, Identifiable {
    var id: String; var family: String; var chapter: Int; var section: String; var objective: String; var level: String
    var concept: String; var difficulty: String; var type: String; var context: String; var prompt: String
    var options: [String]; var answer: Int; var explanation: String; var original: Bool; var version: String
}
struct OfficialSource: Codable, Identifiable {
    var id: String; var title: String; var publisher: String; var version: String; var date: String?; var url: String; var use: String; var accessed: String
}
enum StudyMode: String, Codable, CaseIterable {
    case practice, diagnostic, exam, vocabulary
    var title: String { switch self { case .practice: "Quick practice"; case .diagnostic: "Your diagnostic"; case .exam: "Mock exam"; case .vocabulary: "Word practice" } }
}
enum Confidence: String, Codable, CaseIterable {
    case guess, unsure, confident
    var title: String { rawValue.capitalized }
}
struct SavedAnswer: Codable {
    var choice: Int; var confidence: Confidence; var reasoning: String; var seconds: Double
}
struct QuestionAttempt: Codable, Identifiable {
    var id = UUID().uuidString
    var sessionID: String; var questionID: String; var family: String; var objective: String; var concept: String
    var chapter: Int; var mode: StudyMode; var choice: Int?; var correct: Bool; var confidence: Confidence
    var at: Date; var seconds: Double; var reasoning: String; var contentVersion: String
}
struct StudySession: Codable, Identifiable {
    var id = UUID().uuidString
    var mode: StudyMode; var questionIDs: [String]; var cursor = 0; var answers: [String: SavedAnswer] = [:]
    var overrides: [String: AcademyQuestion] = [:]; var flags: Set<Int> = []
    var startedAt: Date; var openedAt: Date; var deadline: Date?; var finishedAt: Date?
    var unseen: Bool; var targetCount: Int; var chapterFilter: Int?; var conceptFilter: String?
    var contentVersion: String
    var minutes: Int { deadline.map { Int(($0.timeIntervalSince(startedAt) / 60).rounded()) } ?? 0 }
    var currentID: String { questionIDs[cursor] }
}
struct LearningState: Codable {
    var schemaVersion = 1
    var catalogVersion: String
    var attempts: [QuestionAttempt] = []
    var sessions: [StudySession] = []
    var exposedFamilies: Set<String> = []
    var bookmarkedConcepts: Set<String> = []
    var lastOpenedAt: Date = Date()
}
enum AcademyError: LocalizedError {
    case invalidCatalog, activeSession, notEnoughUnseen, missingSession, invalidAnswer, answerFirst, invalidBackup
    var errorDescription: String? {
        switch self {
        case .invalidCatalog: "The bundled question library could not be verified. Please reinstall the app without deleting your saved progress."
        case .activeSession: "You already have a session in progress. Resume or finish it first."
        case .notEnoughUnseen: "There aren’t enough unseen questions left in every required exam group. Choose a mixed mock for more practice. Mixed mocks do not count as unseen readiness evidence."
        case .missingSession: "This study session is no longer available."
        case .invalidAnswer: "Choose an answer and your confidence before continuing."
        case .answerFirst: "Check your answer before continuing."
        case .invalidBackup: "This file is not a compatible Academy backup. Your current progress has been kept."
        }
    }
}
struct ObjectiveEvidence: Identifiable {
    var id: String; var score: Int?; var vocabularyScore: Int?; var uniqueFamilies: Int; var count: Int
    var dueAt: Date?; var label: String; var isDue: Bool
}
struct ChapterEvidence: Identifiable {
    var id: Int; var name: String; var score: Int?; var assessed: Int; var total: Int
}
struct ExamResult: Identifiable {
    var id: String; var date: Date; var score: Int; var unseen: Bool; var minutes: Int
    var percentage: Int { Int((Double(score) / 40 * 100).rounded()) }
    var passed: Bool { score >= 26 }
}

enum AcademyEngine {
    static let chapterNames = ["Fundamentals", "SDLC & testing", "Static testing", "Analysis & design", "Managing testing", "Test tools"]
    static let chapterIcons = ["square.stack.3d.up", "arrow.triangle.branch", "doc.text.magnifyingglass", "point.3.connected.trianglepath.dotted", "slider.horizontal.3", "wrench.and.screwdriver"]
    // Official ISTQB Exam Structure Tables v1.19, pp. 4–5. Counts apply to distinct objectives in each group.
    static let groups: [(Int, [String])] = [
        (1,["1.1.1","1.2.2"]),(1,["1.5.2"]),(1,["1.1.2","1.2.1","1.2.3"]),(1,["1.3.1"]),(3,["1.4.1","1.4.2","1.4.3","1.4.4","1.4.5"]),(1,["1.5.1","1.5.3"]),
        (1,["2.1.2"]),(1,["2.1.3"]),(1,["2.2.1","2.2.2"]),(1,["2.2.3","2.3.1"]),(1,["2.1.1","2.1.6"]),(1,["2.1.4","2.1.5"]),
        (2,["3.1.1","3.2.1","3.2.3","3.2.5"]),(1,["3.1.2","3.1.3"]),(1,["3.2.2","3.2.4"]),
        (1,["4.1.1"]),(2,["4.3.1","4.3.2","4.3.3"]),(2,["4.4.1","4.4.2","4.4.3"]),(1,["4.5.1","4.5.2"]),(5,["4.2.1","4.2.2","4.2.3","4.2.4","4.5.3"]),
        (1,["5.1.2","5.1.6","5.2.1","5.3.1"]),(1,["5.1.1","5.1.3"]),(1,["5.1.7"]),(1,["5.2.2","5.2.3","5.2.4"]),(1,["5.3.2","5.3.3"]),(1,["5.4.1"]),(3,["5.1.4","5.1.5","5.5.1"]),
        (1,["6.1.1"]),(1,["6.2.1"])
    ]
    static func evidence(_ lo: String, state: LearningState, now: Date = Date()) -> ObjectiveEvidence {
        let attempts = state.attempts.filter { $0.objective == lo && $0.mode != .vocabulary }
        let recent = Array(attempts.suffix(6)); let unique = Set(attempts.map(\.family)).count
        let score: Int? = recent.isEmpty ? nil : Int((recent.reduce(0.0) { $0 + ($1.correct ? ($1.confidence == .confident ? 1 : 0.75) : 0) } / Double(recent.count) * 100).rounded())
        let words = state.attempts.filter { $0.objective == lo && $0.mode == .vocabulary }.suffix(4)
        let wordScore: Int? = words.isEmpty ? nil : Int((Double(words.filter(\.correct).count) / Double(words.count) * 100).rounded())
        var due: Date?; var label = "Not assessed"
        if let last = attempts.last {
            let streak = attempts.reversed().prefix { $0.correct && $0.confidence == .confident }.count
            let days = [1,3,7,14,30][max(0,min(streak - 1,4))]
            due = last.at.addingTimeInterval(last.correct && last.confidence == .confident ? Double(days) * 86400 : 600)
            let previouslyStrong = attempts.dropLast().filter { $0.correct && $0.confidence == .confident }.count >= 2
            if (previouslyStrong && !last.correct) || (streak >= 2 && due! <= now) { label = "Time to refresh" }
            else if (score ?? 0) >= 80 && unique >= 2 && (wordScore ?? 0) >= 75 { label = "Concept + terminology" }
            else if (score ?? 0) >= 75 && wordScore != nil && wordScore! < 75 { label = "Terminology gap" }
            else if (score ?? 0) >= 75 { label = "Concept understood" }
            else if (score ?? 0) > 35 { label = "Developing understanding" }
            else { label = "Concept needs practice" }
        }
        return ObjectiveEvidence(id: lo, score: score, vocabularyScore: wordScore, uniqueFamilies: unique, count: attempts.count, dueAt: due, label: label, isDue: due.map { $0 <= now } ?? false)
    }
    static func chapters(catalog: AcademyCatalog, state: LearningState) -> [ChapterEvidence] {
        (1...6).map { number in
            let objectives = catalog.objectives.filter { $0.chapter == number }
            let scores = objectives.compactMap { evidence($0.id, state: state).score }
            return ChapterEvidence(id: number, name: chapterNames[number-1], score: scores.isEmpty ? nil : Int((Double(scores.reduce(0,+)) / Double(scores.count)).rounded()), assessed: scores.count, total: objectives.count)
        }
    }
    static func mockResults(_ state: LearningState) -> [ExamResult] {
        state.sessions.filter { $0.mode == .exam && $0.finishedAt != nil }.map { s in
            ExamResult(id:s.id,date:s.finishedAt!,score:state.attempts.filter { $0.sessionID == s.id && $0.correct }.count,unseen:s.unseen,minutes:s.minutes)
        }
    }
    static func ready(catalog: AcademyCatalog, state: LearningState) -> Bool {
        let mocks = mockResults(state).filter(\.unseen).suffix(2)
        return mocks.count == 2 && mocks.allSatisfy { $0.score >= 34 } && catalog.objectives.allSatisfy {
            let e = evidence($0.id, state:state); return e.uniqueFamilies >= 2 && (e.score ?? 0) >= 65
        } && chapters(catalog:catalog,state:state).allSatisfy { ($0.score ?? 0) >= 75 }
    }
    static func examIDs(catalog: AcademyCatalog, state: LearningState, unseen: Bool) throws -> [String] {
        var ids: [String] = []
        for (count, concepts) in groups {
            let available = concepts.shuffled().compactMap { concept in
                catalog.questions.filter { $0.concept == concept && (!unseen || !state.exposedFamilies.contains($0.family)) }.randomElement()
            }
            guard available.count >= count else { throw AcademyError.notEnoughUnseen }
            ids += available.prefix(count).map(\.id)
        }
        guard ids.count == 40 else { throw AcademyError.invalidCatalog }
        return ids.shuffled()
    }
    static func choose(catalog: AcademyCatalog, state: LearningState, chapter: Int? = nil, concept: String? = nil, exclude: String? = nil, vocabulary: Bool = false) throws -> AcademyQuestion {
        var pool = catalog.questions.filter { (chapter == nil || $0.chapter == chapter) && (concept == nil || $0.concept == concept) }
        if pool.contains(where: { $0.id != exclude }) { pool.removeAll { $0.id == exclude } }
        func rank(_ q: AcademyQuestion) -> Int {
            let e = evidence(q.objective, state:state)
            if vocabulary { return e.vocabularyScore ?? -100 }
            return (e.isDue ? -200 : 0) + (e.score ?? -50) + (state.exposedFamilies.contains(q.family) ? 150 : 0)
        }
        guard var q = pool.shuffled().min(by: { rank($0) < rank($1) }) else { throw AcademyError.invalidCatalog }
        if vocabulary, let c = catalog.concept(q.concept) {
            let alternatives = catalog.concepts.filter { $0.id != c.id }.shuffled().prefix(3).map(\.term)
            q.options = ([c.term] + alternatives).shuffled(); q.answer = q.options.firstIndex(of:c.term)!
            q.prompt = "Which ISTQB concept matches your words?\n\n“\(c.intuitive)”"
            q.id += "-word-" + UUID().uuidString; q.context = "Vocabulary"; q.type = "terminology"
        }
        return q
    }
    static func start(_ mode: StudyMode, catalog: AcademyCatalog, state: inout LearningState, chapter: Int? = nil, concept: String? = nil, extended: Bool = false, unseen: Bool = true, now: Date = Date()) throws -> String {
        guard !state.sessions.contains(where: { $0.finishedAt == nil }) else { throw AcademyError.activeSession }
        var ids: [String] = []; var overrides: [String: AcademyQuestion] = [:]
        if mode == .exam { ids = try examIDs(catalog:catalog,state:state,unseen:unseen) }
        else if mode == .diagnostic {
            var queues = (1...6).map { number in catalog.objectives.filter { $0.chapter == number }.shuffled() }
            while queues.contains(where: { !$0.isEmpty }) {
                for index in queues.indices where !queues[index].isEmpty {
                    let lo = queues[index].removeFirst()
                    ids.append(try choose(catalog:catalog,state:state,concept:String(lo.id.dropFirst(3))).id)
                }
            }
        } else {
            let q = try choose(catalog:catalog,state:state,chapter:chapter,concept:concept,vocabulary:mode == .vocabulary)
            ids = [q.id]; if mode == .vocabulary { overrides[q.id] = q }
        }
        let allUnseen = mode == .exam && ids.allSatisfy { id in catalog.question(id).map { !state.exposedFamilies.contains($0.family) } ?? false }
        var session = StudySession(mode:mode,questionIDs:ids,startedAt:now,openedAt:now,deadline:mode == .exam ? now.addingTimeInterval(extended ? 4500 : 3600) : nil,unseen:allUnseen,targetCount:mode == .exam ? 40 : mode == .diagnostic ? 64 : 5,chapterFilter:chapter,conceptFilter:concept,contentVersion:catalog.contentVersion)
        session.overrides = overrides
        state.sessions.append(session)
        if mode != .vocabulary, let q = catalog.question(ids[0]) { state.exposedFamilies.insert(q.family) }
        return session.id
    }
    static func question(session: StudySession, catalog: AcademyCatalog) throws -> AcademyQuestion {
        guard session.questionIDs.indices.contains(session.cursor), let q = session.overrides[session.currentID] ?? catalog.question(session.currentID) else { throw AcademyError.invalidCatalog }
        return q
    }
    static func appendAttempt(session: StudySession, question: AcademyQuestion, answer: SavedAnswer?, state: inout LearningState, now: Date) {
        state.attempts.append(QuestionAttempt(sessionID:session.id,questionID:question.id,family:question.family,objective:question.objective,concept:question.concept,chapter:question.chapter,mode:session.mode,choice:answer?.choice,correct:answer?.choice == question.answer,confidence:answer?.confidence ?? .unsure,at:now,seconds:answer?.seconds ?? 0,reasoning:answer?.reasoning ?? "",contentVersion:session.contentVersion))
    }
    static func answer(sessionID: String, questionID: String, choice: Int, confidence: Confidence, reasoning: String, catalog: AcademyCatalog, state: inout LearningState, now: Date = Date()) throws {
        guard let index = state.sessions.firstIndex(where: { $0.id == sessionID }) else { throw AcademyError.missingSession }
        var s = state.sessions[index]
        guard s.finishedAt == nil else { return }
        if let deadline = s.deadline, now >= deadline { try finish(sessionID:sessionID,catalog:catalog,state:&state,now:now); return }
        guard s.currentID == questionID, (0..<4).contains(choice) else { throw AcademyError.invalidAnswer }
        if s.mode != .exam && s.answers[questionID] != nil { return }
        let q = try question(session:s,catalog:catalog)
        let seconds = (s.answers[questionID]?.seconds ?? 0) + max(0,min(300,now.timeIntervalSince(s.openedAt)))
        let a = SavedAnswer(choice:choice,confidence:confidence,reasoning:String(reasoning.prefix(1200)),seconds:seconds)
        s.answers[questionID] = a; s.openedAt = now
        if s.mode != .exam { appendAttempt(session:s,question:q,answer:a,state:&state,now:now) }
        state.sessions[index] = s
    }
    static func next(sessionID: String, catalog: AcademyCatalog, state: inout LearningState, now: Date = Date()) throws {
        guard let index = state.sessions.firstIndex(where: { $0.id == sessionID }) else { throw AcademyError.missingSession }
        var s = state.sessions[index]; guard s.finishedAt == nil else { return }
        if let deadline = s.deadline, now >= deadline { try finish(sessionID:sessionID,catalog:catalog,state:&state,now:now); return }
        guard s.mode == .exam || s.answers[s.currentID] != nil else { throw AcademyError.answerFirst }
        if s.cursor + 1 >= s.targetCount { if s.mode != .exam { try finish(sessionID:sessionID,catalog:catalog,state:&state,now:now) }; return }
        if s.mode == .practice || s.mode == .vocabulary {
            let current = try question(session:s,catalog:catalog)
            let last = state.attempts.last { $0.sessionID == s.id }
            let focus = last.map { !$0.correct || $0.confidence != .confident } == true ? current.concept : s.conceptFilter
            let q = try choose(catalog:catalog,state:state,chapter:s.chapterFilter,concept:focus,exclude:current.id,vocabulary:s.mode == .vocabulary)
            s.questionIDs.append(q.id); s.answers[q.id] = nil
            if s.mode == .vocabulary { s.overrides[q.id] = q }
        }
        s.cursor += 1; s.openedAt = now
        if s.mode != .vocabulary, let q = catalog.question(s.currentID) { state.exposedFamilies.insert(q.family) }
        state.sessions[index] = s
    }
    static func navigate(sessionID: String, cursor: Int, catalog: AcademyCatalog, state: inout LearningState, now: Date = Date()) throws {
        guard let index = state.sessions.firstIndex(where: { $0.id == sessionID }), state.sessions[index].mode == .exam,
              state.sessions[index].questionIDs.indices.contains(cursor) else { throw AcademyError.missingSession }
        guard state.sessions[index].finishedAt == nil else { return }
        if let deadline = state.sessions[index].deadline, now >= deadline { try finish(sessionID:sessionID,catalog:catalog,state:&state,now:now); return }
        state.sessions[index].cursor = cursor; state.sessions[index].openedAt = now
        if let q = catalog.question(state.sessions[index].currentID) { state.exposedFamilies.insert(q.family) }
    }
    static func finish(sessionID: String, catalog: AcademyCatalog, state: inout LearningState, now: Date = Date()) throws {
        guard let index = state.sessions.firstIndex(where: { $0.id == sessionID }) else { throw AcademyError.missingSession }
        let s = state.sessions[index]; guard s.finishedAt == nil else { return }
        if s.mode == .exam {
            for id in s.questionIDs {
                guard let q = catalog.question(id) else { throw AcademyError.invalidCatalog }
                appendAttempt(session:s,question:q,answer:s.answers[id],state:&state,now:min(now,s.deadline ?? now))
                state.exposedFamilies.insert(q.family)
            }
        }
        state.sessions[index].finishedAt = now
    }
    static func expire(catalog: AcademyCatalog, state: inout LearningState, now: Date = Date()) throws {
        for s in state.sessions where s.finishedAt == nil && s.deadline.map({ $0 <= now }) == true { try finish(sessionID:s.id,catalog:catalog,state:&state,now:now) }
    }
    static func validateBackup(_ state: LearningState, catalog: AcademyCatalog) throws {
        guard state.schemaVersion == 1, state.catalogVersion == catalog.contentVersion,
              state.attempts.count < 100_000, state.sessions.count < 20_000,
              Set(state.attempts.map(\.id)).count == state.attempts.count,
              Set(state.sessions.map(\.id)).count == state.sessions.count,
              state.sessions.filter({ $0.finishedAt == nil }).count <= 1 else { throw AcademyError.invalidBackup }
        for s in state.sessions {
            guard !s.questionIDs.isEmpty, s.questionIDs.indices.contains(s.cursor), (1...80).contains(s.targetCount),
                  s.contentVersion == catalog.contentVersion, s.questionIDs.count <= s.targetCount,
                  s.flags.allSatisfy({ s.questionIDs.indices.contains($0) }),
                  s.mode != .exam || (s.questionIDs.count == 40 && s.targetCount == 40 && s.deadline != nil && Set(s.questionIDs).count == 40),
                  s.questionIDs.allSatisfy({ catalog.question($0) != nil || s.overrides[$0] != nil }) else { throw AcademyError.invalidBackup }
            for (id,q) in s.overrides {
                guard s.mode == .vocabulary, id == q.id, q.options.count == 4, (0..<4).contains(q.answer),
                      catalog.concept(q.concept)?.objective == q.objective,
                      catalog.objectives.first(where:{$0.id == q.objective})?.chapter == q.chapter else { throw AcademyError.invalidBackup }
            }
            for (id,a) in s.answers where !s.questionIDs.contains(id) || !(0..<4).contains(a.choice) || !a.seconds.isFinite || a.seconds < 0 || a.reasoning.count > 1200 { throw AcademyError.invalidBackup }
        }
        for a in state.attempts {
            guard let s = state.sessions.first(where:{$0.id == a.sessionID}), let q = s.overrides[a.questionID] ?? catalog.question(a.questionID),
                  s.questionIDs.contains(a.questionID), a.mode == s.mode, a.contentVersion == catalog.contentVersion,
                  q.objective == a.objective, q.concept == a.concept, q.chapter == a.chapter, q.family == a.family,
                  a.choice.map({(0..<4).contains($0)}) ?? true, a.correct == (a.choice == q.answer),
                  a.seconds.isFinite, a.seconds >= 0, a.reasoning.count <= 1200 else { throw AcademyError.invalidBackup }
        }
    }
}
