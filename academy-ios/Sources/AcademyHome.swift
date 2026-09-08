import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: AcademyStore
    @Environment(\.horizontalSizeClass) var sizeClass
    var body: some View {
        PageLayout {
            HStack { Eyebrow(text:"HOP · ISTQB ACADEMY"); Spacer(); Label("Offline ready",systemImage:"checkmark.circle.fill").font(.caption2.weight(.medium)).foregroundStyle(AcademyPalette.jade) }
            if sizeClass == .regular { HStack(alignment:.top,spacing:22) { hero; focus.frame(maxWidth:330) } }
            else { hero }
            HStack(spacing:12) {
                MiniMetric(value:store.accuracy.map { "\($0)%" } ?? "—",label:"Recent accuracy",icon:"scope")
                MiniMetric(value:"\(store.due.count)",label:"Due for review",icon:"arrow.clockwise")
                if sizeClass == .regular { MiniMetric(value:"\(store.studyMinutes)m",label:"Time invested",icon:"clock") }
            }
            if sizeClass != .regular { focus }
            SectionTitle(title:"Your knowledge, mapped",subtitle:"Six chapters. Start with your gaps.")
            AcademyCard {
                ForEach(store.chapters) { chapter in
                    NavigationLink { ChapterDetail(number:chapter.id) } label: { ChapterRow(chapter:chapter,action:{}).allowsHitTesting(false) }.buttonStyle(.plain)
                    if chapter.id < 6 { Divider() }
                }
            }
            Text("Mastery is an estimate from your answers. Unassessed areas stay unknown.").font(.caption).foregroundStyle(.secondary).padding(.horizontal,4)
        }.navigationTitle("Your learning space").navigationBarTitleDisplayMode(.inline)
    }
    private var hero: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack(alignment:.top) {
                VStack(alignment:.leading,spacing:10) {
                    Eyebrow(text:"ON YOUR TIME",color:AcademyPalette.lime)
                    Text(store.state.attempts.isEmpty ? "What do you\nalready know?" : "A little practice.\nMore clarity.")
                        .font(.system(.largeTitle,design:.rounded,weight:.bold)).tracking(-1).fixedSize(horizontal:false,vertical:true)
                }
                Spacer(minLength:5)
                if sizeClass == .regular { MasteryRing(score:store.overall,size:100,light:true) }
            }
            Text(store.state.attempts.isEmpty ? "You’ve built and debugged HOP. Let’s turn that experience into testing knowledge." : "Pick up where you left off. We’ll focus on what needs attention, one question at a time.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.78)).lineSpacing(4)
            if let active = store.active {
                VStack(alignment:.leading,spacing:8) {
                    Text("\(active.mode.title) · question \(active.cursor + 1) of \(active.targetCount)").font(.caption.weight(.semibold)).foregroundStyle(AcademyPalette.lime)
                    PrimaryAction(title:"Continue session",icon:"play.fill",light:true) { store.presentedSession = active.id }
                }
            } else {
                PrimaryAction(title:store.state.attempts.isEmpty ? "Discover my starting point" : "Five questions for today",light:true) { store.start(store.state.attempts.isEmpty ? .diagnostic : .practice) }
            }
            HStack(spacing:6) { Image(systemName:"sparkle"); Text("Question first. Learn only the missing piece.") }.font(.caption2).foregroundStyle(.white.opacity(0.7))
        }.padding(25).frame(maxWidth:.infinity,alignment:.leading)
            .background(LinearGradient(colors:[AcademyPalette.forest,Color(red:0.04,green:0.18,blue:0.15)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:28,style:.continuous))
            .foregroundStyle(.white)
    }
    private var focus: some View {
        AcademyCard {
            Eyebrow(text:store.weak.isEmpty ? "FROM YOUR HOP EXPERIENCE" : "YOUR NEXT FOCUS")
            Image(systemName:store.weak.isEmpty ? "arrow.triangle.branch" : "scope").font(.title).foregroundStyle(AcademyPalette.jade)
            Text(focusTitle).font(.title3.weight(.bold)).fixedSize(horizontal:false,vertical:true)
            Text(store.weak.isEmpty ? "After a fix, how do you know the rest still works? Connect your intuition to the ISTQB term." : "A short retrieval session helps this concept stick. You’ll see a different scenario where one is available.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button { store.start(.practice,concept:focusConcept) } label: { Label("Try a quick challenge",systemImage:"arrow.right").font(.subheadline.weight(.semibold)) }.buttonStyle(.plain).foregroundStyle(AcademyPalette.jade).padding(.vertical,8)
        }
    }
    private var focusConcept: String { store.weak.first.map { String($0.id.dropFirst(3)) } ?? "2.2.3" }
    private var focusTitle: String { store.catalog.concept(focusConcept)?.term ?? "Confirmation & regression" }
}

struct PracticeView: View {
    @EnvironmentObject var store: AcademyStore
    var body: some View {
        PageLayout {
            SectionTitle(title:"Make the next five count.",subtitle:"A short session that adapts to your answers.")
            AcademyCard {
                Label("QUICK CHALLENGE",systemImage:"bolt.fill").font(.caption.weight(.bold)).foregroundStyle(AcademyPalette.jade)
                Text("Start with a question.").font(.title2.bold())
                Text("Answer, choose your confidence, then learn the one concept you need. About five questions per session.").font(.subheadline).foregroundStyle(.secondary)
                PrimaryAction(title:"Start adaptive practice") { store.start(.practice) }
            }
            NavigationLink { ExamLaunchView() } label: {
                HStack(spacing:18) {
                    Image(systemName:"timer").font(.largeTitle).foregroundStyle(AcademyPalette.lime)
                    VStack(alignment:.leading,spacing:6) { Text("The exam room").font(.title3.bold()); Text("40 questions · 60 or 75 minutes").font(.subheadline).foregroundStyle(.white.opacity(0.75)) }
                    Spacer(); Image(systemName:"arrow.up.right")
                }.padding(24).foregroundStyle(.white).background(AcademyPalette.forest,in:RoundedRectangle(cornerRadius:24))
            }.buttonStyle(.plain)
            AcademyCard {
                HStack { Image(systemName:"circle.grid.cross").font(.title2).foregroundStyle(AcademyPalette.jade); SectionTitle(title:"Full-syllabus diagnostic",subtitle:"64 questions, one per learning objective") }
                Text("Find your starting point across all six chapters. Pause whenever you need to; your place is saved.").font(.subheadline).foregroundStyle(.secondary)
                Button("Start or resume diagnostic") { store.start(.diagnostic) }.font(.headline).padding(.vertical,10)
            }
            SectionTitle(title:"Choose an area",subtitle:"Practice a chapter or explore its concepts.")
            AcademyCard {
                ForEach(store.chapters) { chapter in ChapterRow(chapter:chapter) { store.start(.practice,chapter:chapter.id) }; if chapter.id < 6 { Divider() } }
            }
            if !store.due.isEmpty {
                SectionTitle(title:"Ready for a refresh",subtitle:"Spaced reviews from your own history")
                ForEach(store.due.prefix(6)) { item in
                    let concept = store.catalog.concept(String(item.id.dropFirst(3)))
                    Button { store.start(.practice,concept:concept?.id) } label: { AcademyCard { HStack { VStack(alignment:.leading,spacing:6) { Text(concept?.term ?? item.id).font(.headline); Text(item.label).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName:"arrow.clockwise") } } }.buttonStyle(.plain)
                }
            }
        }.navigationTitle("Practice").navigationBarTitleDisplayMode(.large)
    }
}

struct ExamLaunchView: View {
    @EnvironmentObject var store: AcademyStore
    @State private var extended = false
    @State private var unseen = true
    var body: some View {
        PageLayout {
            VStack(alignment:.leading,spacing:20) {
                Eyebrow(text:"A CLEARER MEASURE",color:AcademyPalette.lime)
                Text("One quiet hour.\nAn honest benchmark.").font(.system(.largeTitle,design:.rounded,weight:.bold))
                Text("A timed mock built to the official CTFL structure. No explanations until you finish.").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                HStack(spacing:28) { fact("40","questions"); fact("26","points to pass"); fact(extended ? "75" : "60","minutes") }
            }.padding(26).frame(maxWidth:.infinity,alignment:.leading).foregroundStyle(.white).background(AcademyPalette.forest,in:RoundedRectangle(cornerRadius:28))
            AcademyCard {
                Toggle("Only unseen questions",isOn:$unseen).font(.headline)
                Text("Unseen mocks count toward readiness. Mixed mocks are useful practice and are clearly marked as repeated.").font(.caption).foregroundStyle(.secondary)
                Divider()
                Toggle("Use the 75-minute setting",isOn:$extended).font(.headline)
                Text("For candidates whose first/native language is not English. The official extension requires your declaration when booking.").font(.caption).foregroundStyle(.secondary)
            }
            AcademyCard {
                Label("Before you begin",systemImage:"moon.stars").font(.headline)
                Text("The timer continues if you lock your device or leave the app. Save each answer before moving to another question. You can flag questions and return to them.").font(.subheadline).foregroundStyle(.secondary)
                PrimaryAction(title:store.active == nil ? "Begin timed mock" : "Resume current session",icon:"play.fill") { store.start(.exam,extended:extended,unseen:unseen) }
            }
            Text("Official weighting: 8 / 6 / 4 / 11 / 9 / 2 questions by chapter. K1 / K2 / K3: 8 / 24 / 8. All \(store.catalog.questions.count) Academy questions are original practice items.").font(.caption).foregroundStyle(.secondary)
        }.navigationTitle("Exam simulator").navigationBarTitleDisplayMode(.inline)
    }
    private func fact(_ value: String, _ label: String) -> some View { VStack(alignment:.leading,spacing:5) { Text(value).font(.system(.title,design:.rounded,weight:.bold)); Text(label).font(.caption2).foregroundStyle(.white.opacity(0.75)) } }
}

struct ChapterDetail: View {
    @EnvironmentObject var store: AcademyStore
    let number: Int
    var body: some View {
        PageLayout {
            SectionTitle(title:AcademyEngine.chapterNames[number-1],subtitle:"Objective-level evidence, without guesswork")
            PrimaryAction(title:"Practice this chapter") { store.start(.practice,chapter:number) }
            ForEach(store.catalog.objectives.filter { $0.chapter == number }) { lo in
                let evidence = AcademyEngine.evidence(lo.id,state:store.state)
                NavigationLink { ConceptDetail(conceptID:String(lo.id.dropFirst(3))) } label: {
                    AcademyCard {
                        HStack { Eyebrow(text:"\(lo.id) · \(lo.level)"); Spacer(); Text(evidence.score.map { "\($0)%" } ?? "—").font(.headline).foregroundStyle(AcademyPalette.jade) }
                        Text(lo.title).font(.headline)
                        Text("\(evidence.label) · \(evidence.uniqueFamilies) scenario families").font(.caption).foregroundStyle(.secondary)
                    }
                }.buttonStyle(.plain)
            }
        }.navigationTitle("Concept map").navigationBarTitleDisplayMode(.inline)
    }
}
