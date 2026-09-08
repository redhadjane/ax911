import XCTest
@testable import AcademyCore

final class AcademyTests: XCTestCase {
    var catalog: AcademyCatalog!
    let epoch = Date(timeIntervalSince1970:1_800_000_000)
    override func setUpWithError() throws {
        let url = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/catalog.json")
        catalog = try JSONDecoder().decode(AcademyCatalog.self,from:Data(contentsOf:url))
    }
    func empty() -> LearningState { LearningState(catalogVersion:catalog.contentVersion) }
    func start(_ mode:StudyMode,state:inout LearningState,concept:String? = nil,extended:Bool = false) throws -> String {
        try AcademyEngine.start(mode,catalog:catalog,state:&state,concept:concept,extended:extended,now:epoch)
    }
    func respond(_ id:String,state:inout LearningState,correct:Bool = true,confidence:Confidence = .confident,now:Date? = nil) throws {
        let s=try XCTUnwrap(state.sessions.first(where:{$0.id==id})), q=try AcademyEngine.question(session:s,catalog:catalog)
        try AcademyEngine.answer(sessionID:id,questionID:q.id,choice:correct ? q.answer : (q.answer+1)%4,confidence:confidence,reasoning:"Test reasoning",catalog:catalog,state:&state,now:now ?? epoch.addingTimeInterval(10))
    }
    func testCatalogCoverageAndOriginality() throws {
        try catalog.validate()
        XCTAssertEqual(catalog.questions.count,168)
        XCTAssertEqual(catalog.objectives.count,64)
        XCTAssertEqual(catalog.syllabus,"4.0.1")
        XCTAssertTrue(catalog.questions.allSatisfy(\.original))
        XCTAssertTrue(catalog.questions.contains(where:{$0.context=="HOP"}))
        XCTAssertTrue(catalog.questions.contains(where:{$0.context != "HOP"}))
    }
    func testExamBlueprintAcrossRandomDraws() throws {
        for _ in 0..<100 {
            let ids=try AcademyEngine.examIDs(catalog:catalog,state:empty(),unseen:true)
            let qs=ids.compactMap { catalog.question($0) }
            XCTAssertEqual(Set(ids).count,40)
            XCTAssertEqual((1...6).map { ch in qs.filter{$0.chapter==ch}.count },[8,6,4,11,9,2])
            XCTAssertEqual(["K1","K2","K3"].map { k in qs.filter{$0.level==k}.count },[8,24,8])
            for (count,concepts) in AcademyEngine.groups { XCTAssertEqual(qs.filter { concepts.contains($0.concept) }.count,count) }
        }
    }
    func testDiagnosticAssessesAllObjectivesAndResumes() throws {
        var state=empty(); let id=try start(.diagnostic,state:&state)
        XCTAssertEqual(Set(state.sessions[0].questionIDs.compactMap{catalog.question($0)?.objective}).count,64)
        try respond(id,state:&state)
        try AcademyEngine.next(sessionID:id,catalog:catalog,state:&state,now:epoch.addingTimeInterval(20))
        let restored=try JSONDecoder().decode(LearningState.self,from:JSONEncoder().encode(state))
        try AcademyEngine.validateBackup(restored,catalog:catalog)
        XCTAssertEqual(restored.sessions[0].cursor,1);XCTAssertEqual(restored.attempts.count,1)
    }
    func testSubmittedPracticeCannotDoubleCount() throws {
        var state=empty(); let id=try start(.practice,state:&state)
        try respond(id,state:&state);try respond(id,state:&state,correct:false)
        XCTAssertEqual(state.attempts.count,1);XCTAssertTrue(state.attempts[0].correct)
        XCTAssertThrowsError(try start(.exam,state:&state))
    }
    func testWrongAnswerGetsDifferentScenarioOfSameConcept() throws {
        var state=empty(); let id=try start(.practice,state:&state)
        let q=try AcademyEngine.question(session:state.sessions[0],catalog:catalog)
        try respond(id,state:&state,correct:false)
        try AcademyEngine.next(sessionID:id,catalog:catalog,state:&state)
        let next=try AcademyEngine.question(session:state.sessions[0],catalog:catalog)
        XCTAssertEqual(q.concept,next.concept);XCTAssertNotEqual(q.id,next.id)
    }
    func testFiveQuestionTargetEndsEvenWithRepeatedConcept() throws {
        var state=empty();let id=try start(.practice,state:&state,concept:"1.1.1")
        for _ in 0..<5 { try respond(id,state:&state,correct:false);try AcademyEngine.next(sessionID:id,catalog:catalog,state:&state) }
        XCTAssertEqual(state.attempts.count,5);XCTAssertNotNil(state.sessions[0].finishedAt)
        try AcademyEngine.validateBackup(state,catalog:catalog)
    }
    func testCannotSkipPracticeButCanSkipExam() throws {
        var state=empty();let id=try start(.practice,state:&state)
        XCTAssertThrowsError(try AcademyEngine.next(sessionID:id,catalog:catalog,state:&state))
        try AcademyEngine.finish(sessionID:id,catalog:catalog,state:&state)
        let exam=try start(.exam,state:&state)
        try AcademyEngine.next(sessionID:exam,catalog:catalog,state:&state,now:epoch)
        XCTAssertEqual(state.sessions.last?.cursor,1)
    }
    func testExamSelectionIsEditableAndHiddenUntilSubmission() throws {
        var state=empty();let id=try start(.exam,state:&state)
        try respond(id,state:&state,correct:false);try respond(id,state:&state)
        XCTAssertEqual(state.attempts.count,0);XCTAssertEqual(state.sessions[0].answers.count,1)
        try AcademyEngine.finish(sessionID:id,catalog:catalog,state:&state,now:epoch.addingTimeInterval(100))
        try AcademyEngine.finish(sessionID:id,catalog:catalog,state:&state)
        XCTAssertEqual(state.attempts.count,40);XCTAssertEqual(state.attempts.filter(\.correct).count,1)
        XCTAssertEqual(state.attempts.filter{$0.choice==nil}.count,39)
    }
    func testExpirationCannotBePausedOrAnsweredLate() throws {
        var state=empty();let id=try start(.exam,state:&state)
        XCTAssertEqual(state.sessions[0].deadline,epoch.addingTimeInterval(3600))
        try respond(id,state:&state,now:epoch.addingTimeInterval(3600))
        XCTAssertNotNil(state.sessions[0].finishedAt);XCTAssertEqual(state.attempts.filter(\.correct).count,0)
        try AcademyEngine.navigate(sessionID:id,cursor:3,catalog:catalog,state:&state)
        XCTAssertEqual(state.sessions[0].cursor,0)
        try AcademyEngine.expire(catalog:catalog,state:&state);XCTAssertEqual(state.attempts.count,40)
    }
    func testExtendedTimerSurvivesBackupRoundTrip() throws {
        var state=empty();_ = try start(.exam,state:&state,extended:true)
        state=try JSONDecoder().decode(LearningState.self,from:JSONEncoder().encode(state))
        XCTAssertEqual(state.sessions[0].minutes,75)
        try AcademyEngine.expire(catalog:catalog,state:&state,now:epoch.addingTimeInterval(4499))
        XCTAssertNil(state.sessions[0].finishedAt)
        try AcademyEngine.expire(catalog:catalog,state:&state,now:epoch.addingTimeInterval(4501))
        XCTAssertNotNil(state.sessions[0].finishedAt)
    }
    func testUnseenExcludesExposureAndFailsWhenExhausted() throws {
        var state=empty();let first=try AcademyEngine.examIDs(catalog:catalog,state:state,unseen:true)
        first.forEach { state.exposedFamilies.insert(catalog.question($0)!.family) }
        let next=try AcademyEngine.examIDs(catalog:catalog,state:state,unseen:true)
        XCTAssertTrue(Set(first).isDisjoint(with:Set(next)))
        state.exposedFamilies=Set(catalog.questions.map(\.family))
        XCTAssertThrowsError(try AcademyEngine.examIDs(catalog:catalog,state:state,unseen:true))
        XCTAssertEqual(try AcademyEngine.examIDs(catalog:catalog,state:state,unseen:false).count,40)
    }
    func testViewingExamQuestionConsumesUnseenFamily() throws {
        var state=empty();let id=try start(.exam,state:&state)
        XCTAssertEqual(state.exposedFamilies.count,1)
        try AcademyEngine.navigate(sessionID:id,cursor:10,catalog:catalog,state:&state,now:epoch)
        XCTAssertEqual(state.exposedFamilies.count,2)
        try AcademyEngine.finish(sessionID:id,catalog:catalog,state:&state,now:epoch)
        XCTAssertEqual(state.exposedFamilies.count,40)
    }
    func testVocabularyDoesNotCreateConceptMasteryOrExposeScenarios() throws {
        var state=empty();let id=try start(.vocabulary,state:&state)
        let q=try AcademyEngine.question(session:state.sessions[0],catalog:catalog)
        XCTAssertEqual(Set(q.options).count,4)
        XCTAssertEqual(q.explanation,catalog.concept(q.concept)?.lesson)
        try respond(id,state:&state)
        let e=AcademyEngine.evidence(q.objective,state:state,now:epoch)
        XCTAssertNil(e.score);XCTAssertEqual(e.vocabularyScore,100);XCTAssertTrue(state.exposedFamilies.isEmpty)
        try AcademyEngine.validateBackup(state,catalog:catalog)
    }
    func testUncertaintyReturnsSoonAndConfidenceSpacesReview() throws {
        var state=empty();let id=try start(.practice,state:&state,concept:"4.2.2")
        try respond(id,state:&state,confidence:.unsure)
        let lo=state.attempts[0].objective
        var e=AcademyEngine.evidence(lo,state:state,now:epoch.addingTimeInterval(611))
        XCTAssertEqual(e.score,75);XCTAssertTrue(e.isDue)
        try AcademyEngine.next(sessionID:id,catalog:catalog,state:&state)
        try respond(id,state:&state,now:epoch.addingTimeInterval(1000))
        e=AcademyEngine.evidence(lo,state:state,now:epoch.addingTimeInterval(1001))
        XCTAssertFalse(e.isDue);XCTAssertEqual(e.uniqueFamilies,2)
    }
    func testReadinessRequiresUnseenMocksAndCoverage() throws {
        var state=empty()
        XCTAssertFalse(AcademyEngine.ready(catalog:catalog,state:state))
        for _ in 0..<2 {
            let id=try start(.exam,state:&state)
            for i in 0..<40 {
                try AcademyEngine.navigate(sessionID:id,cursor:i,catalog:catalog,state:&state,now:epoch)
                try respond(id,state:&state)
            }
            try AcademyEngine.finish(sessionID:id,catalog:catalog,state:&state,now:epoch.addingTimeInterval(100))
        }
        XCTAssertEqual(AcademyEngine.mockResults(state).filter{$0.unseen && $0.score==40}.count,2)
        XCTAssertFalse(AcademyEngine.ready(catalog:catalog,state:state),"Two strong mocks alone leave unassessed objectives")
        for lo in catalog.objectives {
            let qs=catalog.questions.filter{$0.objective==lo.id}.prefix(2)
            let session=StudySession(mode:.practice,questionIDs:qs.map(\.id),startedAt:epoch,openedAt:epoch,finishedAt:epoch,unseen:false,targetCount:5,contentVersion:catalog.contentVersion)
            state.sessions.append(session)
            for q in qs { AcademyEngine.appendAttempt(session:session,question:q,answer:SavedAnswer(choice:q.answer,confidence:.confident,reasoning:"",seconds:10),state:&state,now:epoch) }
        }
        XCTAssertTrue(AcademyEngine.ready(catalog:catalog,state:state))
        try AcademyEngine.validateBackup(state,catalog:catalog)
    }
    func testBackupRejectsCorruptIndexChoiceAndWrongVersion() throws {
        var state=empty();let id=try start(.practice,state:&state);try respond(id,state:&state)
        var broken=state;broken.sessions[0].cursor=999
        XCTAssertThrowsError(try AcademyEngine.validateBackup(broken,catalog:catalog))
        broken=state;broken.attempts[0].choice=7
        XCTAssertThrowsError(try AcademyEngine.validateBackup(broken,catalog:catalog))
        broken=state;broken.catalogVersion="old"
        XCTAssertThrowsError(try AcademyEngine.validateBackup(broken,catalog:catalog))
        broken=state;broken.attempts[0].correct.toggle()
        XCTAssertThrowsError(try AcademyEngine.validateBackup(broken,catalog:catalog))
    }
}
