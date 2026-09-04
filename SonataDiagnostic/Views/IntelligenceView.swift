import SwiftUI

struct IntelligenceView: View {
    @EnvironmentObject private var obd: OBDLinkCXManager
    let demoMode: Bool
    let scenario: DemoScenario
    @State private var question = ""
    @State private var conversation: [GuideMessage] = []

    private var snapshot: VehicleSnapshot { demoMode ? DemoVehicle.snapshot(for: scenario) : obd.snapshot }
    private let suggestions = ["Can I keep driving?", "What should I inspect first?", "Write a mechanic summary"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { reader in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            ScreenHeader(title: "Vehicle intelligence", subtitle: "Private guidance grounded in this scan—not generic guesses.")
                            StatusBadge(text: "ON DEVICE", color: SDTheme.green)
                        }
                        intelligenceCard
                        SectionLabel(text: "Ask about this scan")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestions, id: \.self) { prompt in
                                    Button(prompt) { ask(prompt) }
                                        .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(.white)
                                        .padding(.horizontal, 12).frame(height: 36)
                                        .background(SDTheme.panelRaised, in: Capsule()).overlay(Capsule().stroke(SDTheme.border, lineWidth: 0.7))
                                }
                            }
                        }
                        ForEach(conversation) { message in
                            GuideBubble(message: message).id(message.id)
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)
                }
                .onChange(of: conversation.count) { _ in if let id = conversation.last?.id { withAnimation { reader.scrollTo(id, anchor: .bottom) } } }
            }

            HStack(spacing: 10) {
                TextField("Ask about your scan…", text: $question, axis: .vertical)
                    .font(.system(size: 13.5)).lineLimit(1...3).padding(.horizontal, 14).frame(minHeight: 44)
                    .background(SDTheme.panel, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(SDTheme.border, lineWidth: 0.7))
                Button { ask(question) } label: {
                    Image(systemName: "arrow.up").font(.system(size: 15, weight: .bold)).foregroundStyle(.black).frame(width: 44, height: 44).background(SDTheme.green, in: Circle())
                }.disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(.horizontal, 16).padding(.vertical, 10).background(SDTheme.background.opacity(0.96)).overlay(alignment: .top) { Rectangle().fill(SDTheme.border).frame(height: 0.7) }
        }.background(Color.clear)
    }

    private var intelligenceCard: some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                Circle().fill((snapshot.dtcs.isEmpty ? SDTheme.green : SDTheme.amber).opacity(0.11))
                Image(systemName: "sparkles").font(.system(size: 18, weight: .semibold)).foregroundStyle(snapshot.dtcs.isEmpty ? SDTheme.green : SDTheme.amber)
            }.frame(width: 43, height: 43)
            VStack(alignment: .leading, spacing: 6) {
                Text(summaryTitle).font(.system(size: 15, weight: .bold))
                Text(summaryBody).font(.system(size: 12)).foregroundStyle(SDTheme.muted).lineSpacing(3)
                HStack(spacing: 6) {
                    Label(snapshot.dtcs.isEmpty ? "No active DTC" : snapshot.dtcs.joined(separator: ", "), systemImage: "waveform.path.ecg")
                    Spacer()
                    Text(demoMode ? "DEMO DATA" : "LIVE SCAN")
                }.font(.system(size: 9.5, weight: .bold)).foregroundStyle(SDTheme.tertiary)
            }
        }.premiumCard(padding: 15, radius: 19)
    }

    private var summaryTitle: String {
        if !snapshot.hasAnyReading { return "Connect your Sonata to begin" }
        if snapshot.dtcs.contains("P0562") { return "Electrical priority detected" }
        if snapshot.dtcs.contains("P200A") { return "One moderate airflow finding" }
        return "Current scan looks stable"
    }

    private var summaryBody: String {
        if !snapshot.hasAnyReading { return "The guide will use only readings and codes returned by the connected vehicle." }
        if snapshot.dtcs.contains("P0562") { return "Low system voltage can create secondary warnings. Battery condition, charging output, terminals, and grounds should be checked first." }
        if snapshot.dtcs.contains("P200A") { return "The intake runner is not following its command closely enough. Start with linkage, actuator, connector, vacuum routing, and carbon buildup." }
        return "No active engine code was returned. Continue to interpret live values in their operating context."
    }

    private func ask(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        conversation.append(GuideMessage(role: .user, text: clean))
        conversation.append(GuideMessage(role: .guide, text: response(to: clean)))
        question = ""
    }

    private func response(to prompt: String) -> String {
        guard snapshot.hasAnyReading else { return "Connect the OBDLink CX and complete a scan first. I won’t invent an answer without vehicle data." }
        let lower = prompt.lowercased()
        if lower.contains("driv") {
            if snapshot.dtcs.contains("P0562") { return "Treat this as a priority. Low voltage can cause stalling or multiple false warnings. Avoid a long drive until battery and charging output are checked." }
            if snapshot.dtcs.contains("P200A") { return "A short, gentle drive is often possible if the check-engine light is steady and the engine feels normal. Stop if it flashes, power drops sharply, or the engine runs rough." }
            return "This scan found no active engine DTC. That is reassuring, but it cannot replace attention to warning lights, sounds, overheating, or drivability changes."
        }
        if lower.contains("inspect") || lower.contains("first") {
            if snapshot.dtcs.contains("P0562") { return "Start with a battery load test, alternator output under load, then clean and tighten the primary power and ground connections." }
            if snapshot.dtcs.contains("P200A") { return "Inspect intake-runner linkage and actuator movement first, then the connector, wiring, vacuum routing, and carbon buildup." }
        }
        if lower.contains("mechanic") || lower.contains("summary") {
            let codes = snapshot.dtcs.isEmpty ? "No active Mode 03 DTC" : "Active DTC: \(snapshot.dtcs.joined(separator: ", "))"
            return "2015 Hyundai Sonata Sport. \(codes). RPM \(formatReading(snapshot.rpm, suffix: "")); coolant \(formatReading(snapshot.coolantF, suffix: "°F")); module voltage \(formatReading(snapshot.voltage, suffix: " V", digits: 1)). Please verify the fault using manufacturer service information and inspect before replacing parts."
        }
        return summaryBody + " Open Diagnostics for the plain-language explanation, measurements, and mechanic-ready inspection path."
    }
}

private struct GuideMessage: Identifiable {
    enum Role { case user, guide }
    let id = UUID()
    let role: Role
    let text: String
}

private struct GuideBubble: View {
    let message: GuideMessage
    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 42) }
            Text(message.text).font(.system(size: 12.5)).foregroundStyle(message.role == .user ? .black : .white).lineSpacing(3)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(message.role == .user ? SDTheme.green : SDTheme.panelRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            if message.role == .guide { Spacer(minLength: 30) }
        }
    }
}
