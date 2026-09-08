import SwiftUI

struct StudyWorkspace: View {
    @EnvironmentObject var store: AcademyStore
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let sessionID: String
    @State private var choice: Int?
    @State private var confidence: Confidence?
    @State private var reasoning = ""
    @State private var now = Date()
    @State private var confirmFinish = false
    @State private var navigator = false
    @State private var showReasoning = false
    private let timer = Timer.publish(every:1,on:.main,in:.common).autoconnect()
    var session: StudySession? { store.session(sessionID) }
    var body: some View {
        NavigationStack {
            Group {
                if let s = session {
                    if s.finishedAt != nil { SessionResults(sessionID:sessionID) }
                    else if let q = store.question(s) { questionPage(s,q).id(q.id) }
                    else { ContentUnavailableView("Question unavailable",systemImage:"exclamationmark.circle") }
                } else { ContentUnavailableView("Session unavailable",systemImage:"questionmark.folder") }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.topBarLeading) { Button { store.presentedSession=nil } label: { Image(systemName:"xmark").font(.subheadline.weight(.semibold)).padding(7) }.accessibilityLabel("Save and close session") }
                ToolbarItem(placement:.principal) {
                    if let s = session {
                        VStack(spacing:2) {
                            Text(s.mode.title).font(.subheadline.weight(.semibold))
                            if let deadline = s.deadline, s.finishedAt == nil {
                                Text(timeLeft(deadline)).font(.system(.caption,design:.monospaced,weight:.bold)).foregroundStyle(deadline.timeIntervalSince(now)<300 ? AcademyPalette.amber : AcademyPalette.jade)
                            } else { Text("Saved on your device").font(.caption2).foregroundStyle(.secondary) }
                        }
                    }
                }
                ToolbarItem(placement:.topBarTrailing) { if session?.finishedAt == nil { Button(session?.mode == .exam ? "Finish" : "End") { confirmFinish=true }.font(.subheadline.weight(.semibold)) } }
            }
            .confirmationDialog(session?.mode == .exam ? "Submit your exam?" : "Finish this study session?",isPresented:$confirmFinish,titleVisibility:.visible) {
                Button(session?.mode == .exam ? "Submit and see results" : "Finish session") { store.finish(sessionID); academyHaptic() }
                Button("Keep going",role:.cancel) {}
            } message: { Text(session?.mode == .exam ? "\(session?.answers.count ?? 0) of 40 answers saved. Unanswered questions score zero." : "Your completed answers remain saved. You can start a fresh practice session whenever you like.") }
            .sheet(isPresented:$navigator) { if let s = session { examNavigator(s) } }
            .onReceive(timer) { now=$0; store.tick() }
            .onChange(of:session?.currentID) { _,_ in syncSelection() }
            .onChange(of:session?.finishedAt) { _,date in if date != nil { navigator=false; confirmFinish=false } }
            .onAppear { syncSelection(); store.tick() }
            .alert("Academy",isPresented:Binding(get:{store.message != nil},set:{if !$0 {store.message=nil}})) { Button("OK",role:.cancel) { store.message=nil } } message: { Text(store.message ?? "") }
        }
    }
    private func syncSelection() {
        guard let s=session else { return }
        let saved=s.answers[s.currentID];choice=saved?.choice;confidence=saved?.confidence;reasoning=saved?.reasoning ?? "";showReasoning = !reasoning.isEmpty
    }
    private func timeLeft(_ deadline: Date) -> String {
        let seconds=max(0,Int(deadline.timeIntervalSince(now)));return String(format:"%02d:%02d remaining",seconds/60,seconds%60)
    }
    private func answered(_ s: StudySession) -> Int { s.mode == .exam ? s.answers.count : store.state.attempts.filter { $0.sessionID == s.id }.count }
    private func questionPage(_ s: StudySession, _ q: AcademyQuestion) -> some View {
        let feedback = s.mode != .exam && s.answers[q.id] != nil
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment:.leading,spacing:22) {
                    questionHeader(s,q)
                    if sizeClass == .regular {
                        HStack(alignment:.top,spacing:24) {
                            questionCard(s,q,feedback:feedback).frame(maxWidth:700)
                            VStack(spacing:20) { sideNote(s); if feedback { AnswerExplanation(question:q,choice:choice,reasoning:reasoning) } }.frame(maxWidth:310)
                        }
                    } else {
                        questionCard(s,q,feedback:feedback)
                        if feedback { AnswerExplanation(question:q,choice:choice,reasoning:reasoning).id("feedback") }
                    }
                    Color.clear.frame(height:10)
                }.padding(.horizontal,sizeClass == .regular ? 30 : 18).padding(.top,18).padding(.bottom,20).frame(maxWidth:1120).frame(maxWidth:.infinity)
            }.background(AcademyPalette.canvas)
                .safeAreaInset(edge:.bottom) { bottomAction(s,q,feedback:feedback) }
                .onChange(of:feedback) { _,value in
                    if value && sizeClass != .regular {
                        if reduceMotion { proxy.scrollTo("feedback",anchor:.top) }
                        else { withAnimation(.easeInOut(duration:0.3)) { proxy.scrollTo("feedback",anchor:.top) } }
                    }
                }
        }
    }
    private func questionHeader(_ s: StudySession, _ q: AcademyQuestion) -> some View {
        VStack(spacing:12) {
            HStack {
                Text("QUESTION \(s.cursor+1) / \(s.targetCount)").font(.system(.caption,design:.rounded,weight:.bold)).tracking(1).accessibilityIdentifier("study.position")
                Spacer()
                if s.mode == .exam { Button { navigator=true } label: { Label("\(answered(s))/40 saved",systemImage:"square.grid.3x3").font(.caption.weight(.semibold)) }.accessibilityIdentifier("exam.navigator") }
                else { Label(q.context,systemImage:q.context == "HOP" ? "building.2" : "globe").font(.caption).foregroundStyle(.secondary) }
            }
            ProgressView(value:Double(s.cursor+1),total:Double(s.targetCount)).tint(AcademyPalette.jade)
        }
    }
    private func questionCard(_ s: StudySession, _ q: AcademyQuestion, feedback: Bool) -> some View {
        AcademyCard(padding:sizeClass == .regular ? 30 : 22) {
            HStack {
                Eyebrow(text:s.mode == .vocabulary ? "IN YOUR WORDS" : s.mode == .exam ? "ORIGINAL EXAM PRACTICE" : "THINK IT THROUGH")
                Spacer()
                Button { store.flag(s.id) } label: { Image(systemName:s.flags.contains(s.cursor) ? "flag.fill" : "flag").padding(9).foregroundStyle(s.flags.contains(s.cursor) ? AcademyPalette.amber : Color.secondary) }.accessibilityLabel(s.flags.contains(s.cursor) ? "Unflag question" : "Flag for review").keyboardShortcut("r",modifiers:[])
            }
            Text(q.prompt).font(.system(sizeClass == .regular ? .title : .title2,design:.rounded,weight:.semibold)).lineSpacing(4).fixedSize(horizontal:false,vertical:true).accessibilityAddTraits(.isHeader)
            Text("Select one answer").font(.caption).foregroundStyle(.secondary)
            VStack(spacing:12) { ForEach(q.options.indices,id:\.self) { index in option(s,q,index,feedback:feedback) } }.padding(.top,5)
            if s.mode != .exam {
                VStack(alignment:.leading,spacing:12) {
                    Text("How sure are you?").font(.subheadline.weight(.semibold))
                    ViewThatFits {
                        HStack(spacing:8) { confidenceButtons(disabled:feedback) }
                        VStack(spacing:8) { confidenceButtons(disabled:feedback) }
                    }
                }.padding(.top,8)
                if !feedback {
                    DisclosureGroup(isExpanded:$showReasoning) {
                        TextField("What made this answer fit?",text:$reasoning,axis:.vertical).lineLimit(2...5).font(.subheadline).padding(12).background(AcademyPalette.canvas,in:RoundedRectangle(cornerRadius:12))
                        Text("Optional. Saved for your review, not graded by AI.").font(.caption2).foregroundStyle(.secondary)
                    } label: { Text("Add your reasoning").font(.caption).foregroundStyle(.secondary) }
                }
            }
            if s.mode == .exam { Label("Answers save when selected",systemImage:"checkmark.shield").font(.caption2).foregroundStyle(.secondary) }
        }
    }
    @ViewBuilder private func confidenceButtons(disabled: Bool) -> some View {
        ForEach(Confidence.allCases,id:\.rawValue) { item in
            Button { confidence=item } label: {
                HStack(spacing:5) { Image(systemName:item == .guess ? "questionmark" : item == .unsure ? "circle.lefthalf.filled" : "checkmark"); Text(item.title) }.font(.subheadline.weight(.medium)).frame(maxWidth:.infinity).padding(.vertical,13).padding(.horizontal,9)
                    .background(confidence == item ? AcademyPalette.jade.opacity(0.15) : AcademyPalette.canvas,in:RoundedRectangle(cornerRadius:13))
                    .overlay(RoundedRectangle(cornerRadius:13).strokeBorder(confidence == item ? AcademyPalette.jade : Color.clear))
                    .foregroundStyle(confidence == item ? AcademyPalette.jade : Color.primary)
            }.buttonStyle(.plain).disabled(disabled).accessibilityAddTraits(confidence == item ? .isSelected : []).accessibilityIdentifier("confidence.\(item.rawValue)")
        }
    }
    private func option(_ s: StudySession, _ q: AcademyQuestion, _ index: Int, feedback: Bool) -> some View {
        let selected = choice == index; let right = feedback && q.answer == index
        let color = right ? AcademyPalette.jade : selected && feedback ? AcademyPalette.amber : AcademyPalette.jade
        return Button {
            choice=index
            if s.mode == .exam { store.answer(s,choice:index,confidence:.unsure,reasoning:"") }
        } label: {
            HStack(alignment:.center,spacing:13) {
                Text(String(UnicodeScalar(65+index)!)).font(.system(.subheadline,design:.rounded,weight:.bold)).frame(width:30,height:32).background(color.opacity(selected || right ? 0.16 : 0.07),in:RoundedRectangle(cornerRadius:9)).foregroundStyle(color)
                Text(q.options[index]).font(.body).multilineTextAlignment(.leading).frame(maxWidth:.infinity,alignment:.leading).fixedSize(horizontal:false,vertical:true)
                if right { Image(systemName:"checkmark.circle.fill").foregroundStyle(AcademyPalette.jade) }
                else if selected { Image(systemName:feedback ? "minus.circle.fill" : "circle.inset.filled").foregroundStyle(color) }
            }.padding(15).frame(minHeight:64)
                .background((selected || right ? color.opacity(0.07) : AcademyPalette.canvas.opacity(0.5)),in:RoundedRectangle(cornerRadius:17))
                .overlay(RoundedRectangle(cornerRadius:17).strokeBorder(selected || right ? color : Color.primary.opacity(0.08),lineWidth:selected || right ? 1.8 : 1))
        }.buttonStyle(.plain).disabled(feedback).keyboardShortcut(KeyEquivalent(Character(String(index+1))),modifiers:[])
            .accessibilityLabel("\(String(UnicodeScalar(65+index)!)). \(q.options[index])").accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier("answer.\(index)")
    }
    private func bottomAction(_ s: StudySession, _ q: AcademyQuestion, feedback: Bool) -> some View {
        VStack(spacing:8) {
            PrimaryAction(title:actionTitle(s,feedback:feedback),icon:feedback ? "arrow.right" : s.mode == .exam ? "arrow.right" : "checkmark") {
                if feedback { store.next(s.id); syncSelection() }
                else if s.mode == .exam {
                    if s.cursor+1 >= s.targetCount { navigator=true } else { store.next(s.id); syncSelection() }
                } else if let choice, let confidence {
                    store.answer(s,choice:choice,confidence:confidence,reasoning:reasoning)
                    academyHaptic(choice == q.answer ? .success : .warning)
                }
            }.disabled(s.mode != .exam && !feedback && (choice == nil || confidence == nil))
                .opacity(s.mode != .exam && !feedback && (choice == nil || confidence == nil) ? 0.5 : 1)
                .keyboardShortcut(.return,modifiers:[])
            if feedback { Text("\(choice == q.answer ? "Keep the momentum." : "A useful gap. Try the next scenario.")").font(.caption2).foregroundStyle(.secondary) }
        }.padding(.horizontal,sizeClass == .regular ? 30 : 18).padding(.top,12).padding(.bottom,10).frame(maxWidth:760).frame(maxWidth:.infinity).background(.regularMaterial)
    }
    private func actionTitle(_ s: StudySession, feedback: Bool) -> String {
        if feedback { return s.cursor+1 >= s.targetCount ? "See your session results" : "Next challenge" }
        if s.mode == .exam { return s.cursor+1 >= s.targetCount ? "Review & submit" : "Next question" }
        return "Check my answer"
    }
    private func sideNote(_ s: StudySession) -> some View {
        AcademyCard {
            Image(systemName:s.mode == .exam ? "timer" : "leaf").font(.title).foregroundStyle(AcademyPalette.jade)
            SectionTitle(title:s.mode == .exam ? "Find your rhythm." : "Your experience counts.")
            Text(s.mode == .exam ? "Read the exact conditions. Flag uncertain questions, keep moving, then return with fresh eyes." : "Start with your own logic. The official term comes after your answer.").font(.subheadline).foregroundStyle(.secondary)
            Divider()
            Text("1–4 select · Return continues · R flags").font(.caption2).foregroundStyle(.secondary)
            if s.mode == .exam { Button("Open question navigator") { navigator=true }.font(.subheadline.weight(.semibold)) }
        }
    }
    private func examNavigator(_ s: StudySession) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:22) {
                    Text("\(s.answers.count) of 40 answered").font(.title2.bold())
                    Text("Filled = saved · Flag = revisit\nThe timer keeps running while you review.").font(.subheadline).foregroundStyle(.secondary)
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:10),count:5),spacing:12) {
                        ForEach(s.questionIDs.indices,id:\.self) { i in
                            Button { store.go(s.id,i); syncSelection(); navigator=false } label: {
                                VStack(spacing:3) { Text("\(i+1)").font(.headline).monospacedDigit(); Image(systemName:s.flags.contains(i) ? "flag.fill" : s.answers[s.questionIDs[i]] != nil ? "checkmark" : "circle").font(.system(size:9)) }.frame(maxWidth:.infinity).frame(height:59)
                                    .background(s.answers[s.questionIDs[i]] != nil ? AcademyPalette.jade.opacity(0.16) : AcademyPalette.canvas,in:RoundedRectangle(cornerRadius:12))
                                    .overlay(RoundedRectangle(cornerRadius:12).strokeBorder(i == s.cursor ? AcademyPalette.jade : .clear,lineWidth:2))
                            }.buttonStyle(.plain).accessibilityLabel("Question \(i+1), \(s.answers[s.questionIDs[i]] != nil ? "answered" : "unanswered")\(s.flags.contains(i) ? ", flagged" : "")").accessibilityIdentifier("exam.question.\(i)")
                        }
                    }
                    PrimaryAction(title:"Submit exam",icon:"checkmark.seal") { navigator=false; confirmFinish=true }
                }.padding(24)
            }.navigationTitle("Question navigator").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement:.cancellationAction) { Button("Done") { navigator=false } } }
        }.presentationDetents([.large])
    }
}

struct AnswerExplanation: View {
    @EnvironmentObject var store: AcademyStore
    let question: AcademyQuestion
    let choice: Int?
    let reasoning: String
    var body: some View {
        let correct = choice == question.answer
        AcademyCard {
            Label(correct ? "That’s right." : "Here’s the missing piece.",systemImage:correct ? "checkmark.circle.fill" : "lightbulb.fill").font(.headline).foregroundStyle(correct ? AcademyPalette.jade : AcademyPalette.amber).accessibilityIdentifier("study.feedback")
            Text(question.options[question.answer]).font(.headline)
            Text(question.explanation).font(.subheadline).lineSpacing(4)
            if !correct, let choice, question.options.indices.contains(choice) { Text("Your choice: \(question.options[choice])").font(.caption).foregroundStyle(.secondary) }
            if let c = store.catalog.concept(question.concept) {
                Divider(); Eyebrow(text:"THE CONCEPT / TERMS"); Text(c.term).font(.headline).foregroundStyle(AcademyPalette.jade)
                Text("Remember: \(c.intuitive).").font(.subheadline).foregroundStyle(.secondary)
                if !reasoning.isEmpty { DisclosureGroup("Your reasoning") { Text(reasoning).font(.subheadline).frame(maxWidth:.infinity,alignment:.leading) } }
                if let source=store.catalog.sources.first(where:{$0.id=="syllabus"}), let lo=store.catalog.objectives.first(where:{$0.id==question.objective}), let url=URL(string:source.url+"#page=\(lo.page)") {
                    Link(destination:url) { Label("Official source · \(question.objective)",systemImage:"arrow.up.right.square").font(.caption) }
                }
            }
        }
    }
}
struct SessionResults: View {
    @EnvironmentObject var store: AcademyStore
    let sessionID: String
    var attempts: [QuestionAttempt] { store.state.attempts.filter { $0.sessionID == sessionID } }
    var body: some View {
        PageLayout {
            if let s=store.session(sessionID) {
                let score=attempts.filter(\.correct).count
                VStack(alignment:.leading,spacing:18) {
                    Eyebrow(text:s.mode == .exam ? "BENCHMARK COMPLETE" : "A LITTLE FURTHER FORWARD",color:AcademyPalette.lime)
                    Text("\(score) / \(attempts.count)").font(.system(size:56,weight:.bold,design:.rounded)).monospacedDigit().accessibilityIdentifier("results.score")
                    Text(s.mode == .exam ? (score >= 26 ? "Above the official pass threshold." : "You’ve found your next study targets.") : "Every answer gives you a clearer next step.").font(.title3.weight(.semibold))
                    if s.mode == .exam { Text(s.unseen ? "Unseen mock · 26/40 passes · Academy aims for 34/40+" : "Mixed practice · Excluded from unseen readiness").font(.caption).foregroundStyle(.white.opacity(0.75)) }
                    PrimaryAction(title:"Back to your learning space",light:true) { store.presentedSession=nil }
                }.padding(26).frame(maxWidth:.infinity,alignment:.leading).foregroundStyle(.white).background(AcademyPalette.forest,in:RoundedRectangle(cornerRadius:28))
                if s.mode == .exam {
                    AcademyCard {
                        SectionTitle(title:"Where to focus next")
                        ForEach(1...6,id:\.self) { chapter in
                            let items=attempts.filter { $0.chapter == chapter }; let right=items.filter(\.correct).count
                            HStack { Text(AcademyEngine.chapterNames[chapter-1]).font(.subheadline); Spacer(); Text("\(right)/\(items.count)").font(.subheadline.weight(.semibold)).foregroundStyle(right == items.count ? AcademyPalette.jade : AcademyPalette.amber) }
                        }
                    }
                }
                SectionTitle(title:"Review your answers",subtitle:"\(attempts.filter { !$0.correct }.count) opportunities to reinforce")
                ForEach(attempts) { a in
                    if let q=s.overrides[a.questionID] ?? store.catalog.question(a.questionID) {
                        AcademyCard {
                            DisclosureGroup {
                                VStack(alignment:.leading,spacing:12) {
                                    Text("Your answer: \(a.choice.map { q.options[$0] } ?? "Unanswered")").font(.subheadline).foregroundStyle(.secondary)
                                    Text("Correct: \(q.options[q.answer])").font(.headline).foregroundStyle(AcademyPalette.jade)
                                    Text(q.explanation).font(.subheadline).lineSpacing(4)
                                    Text(q.objective).font(.caption2).foregroundStyle(.secondary)
                                }.padding(.top,12)
                            } label: { HStack(alignment:.top,spacing:12) { Image(systemName:a.correct ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(a.correct ? AcademyPalette.jade : AcademyPalette.amber); Text(q.prompt).font(.subheadline.weight(.medium)).foregroundStyle(.primary) } }
                        }
                    }
                }
            }
        }.navigationTitle("Session results")
    }
}
