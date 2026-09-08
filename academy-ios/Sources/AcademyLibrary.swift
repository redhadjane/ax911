import SwiftUI
import Charts

struct VocabularyView: View {
    @EnvironmentObject var store: AcademyStore
    @State private var search = ""
    @State private var bookmarkedOnly = false
    var filtered: [LearningConcept] {
        store.catalog.concepts.filter { (!bookmarkedOnly || store.state.bookmarkedConcepts.contains($0.id)) && (search.isEmpty || ($0.term + $0.intuitive).localizedCaseInsensitiveContains(search)) }
    }
    var body: some View {
        PageLayout {
            SectionTitle(title:"You already have the idea.",subtitle:"Give your intuition its official vocabulary.")
            PrimaryAction(title:"Test my terminology",icon:"textformat.abc") { store.start(.vocabulary) }
            Toggle("Saved concepts only",isOn:$bookmarkedOnly).font(.subheadline).padding(.horizontal,4)
            LazyVGrid(columns:[GridItem(.adaptive(minimum:290),spacing:16)],spacing:16) {
                ForEach(filtered) { c in
                    NavigationLink { ConceptDetail(conceptID:c.id) } label: {
                        AcademyCard {
                            Eyebrow(text:"IN YOUR WORDS")
                            Text("“\(c.intuitive)”").font(.title3.weight(.medium)).fixedSize(horizontal:false,vertical:true)
                            HStack { Image(systemName:"arrow.down"); Text(c.term).font(.subheadline.weight(.semibold)); Spacer(); if store.state.bookmarkedConcepts.contains(c.id) { Image(systemName:"bookmark.fill") } }.foregroundStyle(AcademyPalette.jade)
                            Text(c.objective).font(.caption2).foregroundStyle(.secondary)
                        }.frame(maxHeight:.infinity,alignment:.top)
                    }.buttonStyle(.plain)
                }
            }
            if filtered.isEmpty { ContentUnavailableView("No matching concepts",systemImage:"text.magnifyingglass",description:Text("Try a shorter term or turn off Saved concepts only.")) }
        }.navigationTitle("In your words").searchable(text:$search,prompt:"Regression, boundaries, risk…")
    }
}
struct ConceptDetail: View {
    @EnvironmentObject var store: AcademyStore
    let conceptID: String
    var body: some View {
        PageLayout {
            if let c = store.catalog.concept(conceptID) {
                AcademyCard {
                    Eyebrow(text:"FROM INTUITION TO TERMINOLOGY")
                    Text("“\(c.intuitive)”").font(.title2.weight(.medium))
                    Image(systemName:"arrow.down").foregroundStyle(AcademyPalette.jade)
                    Text(c.term).font(.system(.largeTitle,design:.rounded,weight:.bold)).foregroundStyle(AcademyPalette.jade)
                    Text(c.lesson).font(.body).lineSpacing(5)
                }
                let e = AcademyEngine.evidence(c.objective,state:store.state)
                AcademyCard {
                    SectionTitle(title:"Your evidence",subtitle:e.label)
                    HStack { MiniMetric(value:e.score.map { "\($0)%" } ?? "—",label:"Concept estimate",icon:"scope"); MiniMetric(value:e.vocabularyScore.map { "\($0)%" } ?? "—",label:"Vocabulary",icon:"textformat") }
                    Text("\(e.uniqueFamilies) independent scenario families answered. Vocabulary is assessed separately.").font(.caption).foregroundStyle(.secondary)
                }
                PrimaryAction(title:"Challenge this concept") { store.start(.practice,concept:c.id) }
                Button { store.bookmark(c.id) } label: { Label(store.state.bookmarkedConcepts.contains(c.id) ? "Saved to your concepts" : "Save this concept",systemImage:store.state.bookmarkedConcepts.contains(c.id) ? "bookmark.fill" : "bookmark").frame(maxWidth:.infinity).padding(12) }
                if let lo = store.catalog.objectives.first(where: { $0.id == c.objective }), let source = store.catalog.sources.first(where: { $0.id == "syllabus" }), let url = URL(string:source.url + "#page=\(lo.page)") {
                    Link(destination:url) { Label("Official syllabus · \(c.objective)",systemImage:"arrow.up.right.square").font(.subheadline) }
                }
            }
        }.navigationTitle("Concept").navigationBarTitleDisplayMode(.inline)
    }
}
struct DailyStudy: Identifiable { var date: Date; var answered: Int; var accuracy: Double; var id: Date { date } }
struct ProgressDashboard: View {
    @EnvironmentObject var store: AcademyStore
    var days: [DailyStudy] {
        let grouped = Dictionary(grouping:store.state.attempts.filter { $0.mode != .vocabulary }) { Calendar.current.startOfDay(for:$0.at) }
        return grouped.keys.sorted().suffix(14).map { date in
            let a = grouped[date] ?? []; return DailyStudy(date:date,answered:a.count,accuracy:Double(a.filter(\.correct).count)/Double(max(a.count,1))*100)
        }
    }
    var body: some View {
        PageLayout {
            AcademyCard {
                HStack(spacing:24) { MasteryRing(score:store.overall); VStack(alignment:.leading,spacing:8) { Eyebrow(text:"YOUR MOMENTUM"); Text(store.readiness).font(.title.bold()); Text("\(store.evidence.filter { $0.score != nil }.count)/64 objectives assessed").font(.subheadline).foregroundStyle(.secondary) } }
                Text("A confident answer is evidence. Consistent performance on unseen questions is what builds readiness.").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing:12) { MiniMetric(value:"\(store.state.attempts.count)",label:"Answers recorded",icon:"checkmark.bubble"); MiniMetric(value:"\(store.studyMinutes)m",label:"Study time",icon:"clock"); MiniMetric(value:"\(store.streakDays)",label:"Study-day streak",icon:"flame") }
            AcademyCard {
                SectionTitle(title:"Accuracy over time",subtitle:"Daily results from real attempts")
                if days.isEmpty { Text("Your first completed question starts the chart.").foregroundStyle(.secondary).padding(.vertical,25) }
                else {
                    Chart(days) { day in
                        BarMark(x:.value("Day",day.date,unit:.day),y:.value("Accuracy",day.accuracy)).foregroundStyle(AcademyPalette.jade.gradient).cornerRadius(5)
                    }.chartYScale(domain:0...100).chartYAxis { AxisMarks(values:[0,50,100]) { value in AxisGridLine(); AxisValueLabel { if let n = value.as(Int.self) { Text("\(n)%") } } } }.frame(height:190)
                }
                Text("A day's score may reflect a small or repeated set. It is not a predicted exam score.").font(.caption2).foregroundStyle(.secondary)
            }
            AcademyCard {
                SectionTitle(title:"The readiness standard")
                requirement("Two fully unseen mocks at 85%+",icon:"timer")
                requirement("Two scenario families per objective",icon:"square.stack")
                requirement("No major weak chapter",icon:"chart.bar.xaxis")
                Text("Official passing is 26/40 (65%). Academy’s higher target is a study heuristic, not an ISTQB guarantee. Extensive practice can exhaust the unseen bank.").font(.caption).foregroundStyle(.secondary)
            }
            SectionTitle(title:"Your mock exams",subtitle:"Unseen evidence stays separate from mixed practice.")
            if store.mocks.isEmpty { AcademyCard { Label("No completed mocks yet",systemImage:"timer").font(.headline); Text("Take your first benchmark when you feel ready.").font(.subheadline).foregroundStyle(.secondary) } }
            ForEach(store.mocks.reversed()) { exam in
                Button { store.presentedSession = exam.id } label: {
                    AcademyCard {
                        HStack { VStack(alignment:.leading,spacing:7) { Text(exam.date,style:.date).font(.headline); Text("\(exam.unseen ? "Unseen" : "Mixed practice") · \(exam.minutes) min").font(.caption).foregroundStyle(.secondary) }; Spacer(); VStack(alignment:.trailing,spacing:5) { Text("\(exam.score)/40").font(.title2.bold()).monospacedDigit(); Text(exam.passed ? "Passed" : "Keep building").font(.caption.weight(.semibold)).foregroundStyle(exam.passed ? AcademyPalette.jade : AcademyPalette.amber) } }
                    }
                }.buttonStyle(.plain)
            }
        }.navigationTitle("Progress")
    }
    private func requirement(_ text: String, icon: String) -> some View { Label(text,systemImage:icon).font(.subheadline).padding(.vertical,3) }
}
struct SourcesView: View {
    @EnvironmentObject var store: AcademyStore
    var body: some View {
        PageLayout {
            AcademyCard {
                Eyebrow(text:"OFFICIAL FOUNDATIONS")
                Text("Trace every concept.").font(.title.bold())
                Text("CTFL 4.0 · syllabus 4.0.1\nChecked \(store.catalog.verified)").font(.subheadline).foregroundStyle(.secondary)
                Text("Questions, explanations and progress work offline. Official documents open online when you choose a link.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(store.catalog.sources) { source in
                if let url = URL(string:source.url) {
                    Link(destination:url) {
                        AcademyCard {
                            HStack { Text(source.title).font(.headline); Spacer(); Image(systemName:"arrow.up.right").font(.caption) }
                            Text("\(source.publisher) · \(source.version)").font(.caption.weight(.semibold)).foregroundStyle(AcademyPalette.jade)
                            Text(source.use).font(.subheadline).foregroundStyle(.secondary)
                            if let date = source.date { Text("Published / revised \(date)").font(.caption2).foregroundStyle(.tertiary) }
                        }
                    }.buttonStyle(.plain)
                }
            }
            Text("Personal, independent study resource. Original questions are not actual ISTQB examination questions. Syllabus learning-objective excerpts are acknowledged to ISTQB and its authors for non-commercial study. This is not an accredited course.").font(.caption).foregroundStyle(.secondary)
        }.navigationTitle("Official sources")
    }
}

struct AcademySettings: View {
    @EnvironmentObject var store: AcademyStore
    @Environment(\.dismiss) var dismiss
    @AppStorage("academy.appearance") var appearance = "system"
    @AppStorage("academy.haptics") var haptics = true
    @State private var exporting = false
    @State private var importing = false
    @State private var document: ProgressDocument?
    var body: some View {
        NavigationStack {
            Form {
                Section("Make it comfortable") {
                    Picker("Appearance",selection:$appearance) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark · for the evening").tag("dark") }
                    Toggle("Gentle answer feedback",isOn:$haptics)
                    Text("Text follows your iPhone or iPad text-size setting. Animations respect Reduce Motion.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Your progress") {
                    Label("Saved on this device",systemImage:"internaldrive")
                    Text("Study anywhere, including offline. This version does not sync automatically with HOP or between devices. Export a backup to Files or AirDrop, then import it on your other device.").font(.caption).foregroundStyle(.secondary)
                    Button { document=store.exportDocument(); exporting=document != nil } label: { Label("Export progress backup",systemImage:"square.and.arrow.up") }
                    Button { importing=true } label: { Label("Import a progress backup",systemImage:"square.and.arrow.down") }
                }
                Section("Your Academy") {
                    LabeledContent("App version",value:"1.0.0")
                    LabeledContent("Syllabus",value:store.catalog.syllabus)
                    LabeledContent("Original questions",value:String(store.catalog.questions.count))
                    LabeledContent("Learning objectives",value:"64")
                    Text("Free-text reasoning is saved for your review. Understanding and vocabulary use separate answer evidence; the app does not claim to read your reasoning with AI.").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Study settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() } } }
                .fileExporter(isPresented:$exporting,document:document,contentType:.json,defaultFilename:"HOP-Academy-Progress") { result in if case .failure(let error) = result { store.message=error.localizedDescription } }
                .fileImporter(isPresented:$importing,allowedContentTypes:[.json]) { result in switch result { case .success(let url):store.inspectImport(url); case .failure(let error):store.message=error.localizedDescription } }
                .confirmationDialog("Replace this device’s progress with the imported backup?",isPresented:Binding(get:{store.importCandidate != nil},set:{if !$0 {store.importCandidate=nil}}),titleVisibility:.visible) {
                    Button("Restore imported progress") { store.restoreImport() }
                    Button("Cancel",role:.cancel) { store.importCandidate=nil }
                } message: { Text("Your current save will be kept as the previous local backup. Export it first if you want a separate copy. Imported exams keep their original deadlines.") }
                .alert("Academy",isPresented:Binding(get:{store.message != nil},set:{if !$0 {store.message=nil}})) { Button("OK",role:.cancel) { store.message=nil } } message: { Text(store.message ?? "") }
        }
    }
}
