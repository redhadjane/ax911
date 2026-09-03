import SwiftUI

struct ContentView: View {
    @EnvironmentObject var obd: OBDLinkCXManager
    @State private var demoMode = false

    private let green = Color(red: 0.35, green: 0.93, blue: 0.58)
    private let amber = Color(red: 1.00, green: 0.68, blue: 0.24)
    private let panel = Color.white.opacity(0.055)
    private let border = Color.white.opacity(0.11)

    private var data: VehicleSnapshot {
        if demoMode {
            return VehicleSnapshot(
                vin: "5NPE34AF0FH000001",
                dtcs: ["P200A"],
                rpm: 742,
                speedMph: 0,
                coolantF: 194,
                loadPct: 21,
                throttlePct: 13,
                intakeAirF: 86,
                shortFuelTrimPct: 11.8,
                longFuelTrimPct: 7.4,
                fuelPct: 46,
                voltage: 14.1
            )
        }
        return obd.snapshot
    }

    private var isConnectedData: Bool {
        demoMode || obd.state == .finished || obd.state == .reading || obd.state == .connected
    }

    var body: some View {
        TabView {
            NavigationStack { homeView }
                .tabItem { Label("Home", systemImage: "car.side.fill") }
            NavigationStack { healthView }
                .tabItem { Label("Health", systemImage: "heart.text.square.fill") }
            NavigationStack { liveView }
                .tabItem { Label("Live", systemImage: "waveform.path.ecg") }
            NavigationStack { settingsView }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
            NavigationStack { vehicleView }
                .tabItem { Label("Vehicle", systemImage: "cpu.fill") }
        }
        .tint(green)
    }

    private var homeView: some View {
        ScrollView {
            VStack(spacing: 16) {
                header(title: "SONATA DIAGNOSTIC", subtitle: demoMode ? "Demo vehicle" : "OBD-II / CAN is the source of truth")

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Vehicle status").foregroundStyle(.secondary).font(.subheadline)
                            Text(homeStatusTitle).font(.title2.bold())
                        }
                        Spacer()
                        statusPill
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 30).fill(Color.white.opacity(0.025))
                        Image(systemName: "car.side.fill")
                            .resizable().scaledToFit().padding(42)
                            .foregroundStyle(isHealthy ? green.opacity(0.85) : amber.opacity(0.9))
                    }
                    .frame(height: 180)

                    HStack {
                        metricMini("Battery", formatted(data.voltage, suffix: " V", digits: 1))
                        Spacer()
                        metricMini("Engine temp", formatted(data.coolantF, suffix: "°F", digits: 0))
                        Spacer()
                        metricMini("RPM", formatted(data.rpm, suffix: "", digits: 0))
                    }
                }
                .premiumCard(panel: panel, border: border)

                if !data.dtcs.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("NEEDS ATTENTION").font(.caption.bold()).foregroundStyle(amber)
                            Spacer()
                            Text("ENGINE").font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(primaryPlainTitle).font(.title3.bold())
                        Text(primaryPlainExplanation).foregroundStyle(.secondary)
                        NavigationLink {
                            healthView
                        } label: {
                            HStack { Text("See what the car found"); Spacer(); Image(systemName: "chevron.right") }
                                .fontWeight(.semibold)
                        }
                    }
                    .premiumCard(panel: panel, border: border)
                } else if isConnectedData {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CAR HEALTH").font(.caption.bold()).foregroundStyle(green)
                        Text("No active engine fault codes found").font(.title3.bold())
                        Text("This first build checks the standard engine/emissions computer. Hyundai-specific modules come next.")
                            .foregroundStyle(.secondary)
                    }
                    .premiumCard(panel: panel, border: border)
                }

                connectionCard
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("OBDLink CX").font(.headline)
                    Text(connectionMessage).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if isBusy { ProgressView().tint(green) }
            }

            if isBusy {
                ProgressView(value: Double(obd.progress), total: 100).tint(green)
                Text("\(obd.progress)%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    if demoMode { demoMode = false }
                    if isBusy || obd.state == .finished { obd.disconnect() }
                    else { obd.connect() }
                } label: {
                    Label(connectButtonTitle, systemImage: isBusy || obd.state == .finished ? "xmark.circle.fill" : "dot.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PremiumButtonStyle(fill: green))

                Button {
                    demoMode.toggle()
                    if demoMode { obd.disconnect() }
                } label: {
                    Text(demoMode ? "Exit Demo" : "Demo")
                        .frame(minWidth: 70)
                }
                .buttonStyle(PremiumSecondaryButtonStyle())
            }
        }
        .premiumCard(panel: panel, border: border)
    }

    private var healthView: some View {
        ScrollView {
            VStack(spacing: 16) {
                header(title: "CAR HEALTH", subtitle: "Plain English first. Mechanic detail one tap deeper.")

                if data.dtcs.isEmpty {
                    emptyState("No active engine codes", detail: isConnectedData ? "The standard engine computer did not report an active DTC." : "Connect the OBDLink CX or enable Demo Mode from Home.")
                } else {
                    ForEach(data.dtcs, id: \.self) { code in
                        faultCard(code)
                    }

                    readingsCard
                    mechanicCard
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func faultCard(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(severity(for: code)).font(.caption.bold()).foregroundStyle(amber)
                Spacer()
                Text(code).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            Text(plainTitle(for: code)).font(.title2.bold())
            Text(plainExplanation(for: code)).foregroundStyle(.secondary)

            Divider().overlay(border)

            Text("What you may notice").font(.headline)
            Text(symptoms(for: code)).foregroundStyle(.secondary)

            DisclosureGroup("Technical definition") {
                Text(technicalDefinition(for: code))
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .premiumCard(panel: panel, border: border)
    }

    private var readingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ACTUAL vs EXPECTED").font(.caption.bold()).foregroundStyle(green)
            Text("What the car is reporting now").font(.title3.bold())
            Text("Expected ranges are diagnostic context, not a replacement for Hyundai service specifications under the exact test condition.")
                .font(.caption).foregroundStyle(.secondary)

            readingRow("Charging voltage", data.voltage, "V", expected: engineRunning ? "13.5–14.8 V running" : "~12.4–12.8 V engine off", normal: voltageNormal)
            readingRow("Coolant temperature", data.coolantF, "°F", expected: "~185–220°F warm", normal: coolantNormal)
            readingRow("Short fuel trim", data.shortFuelTrimPct, "%", expected: "Near 0%; usually within ±10%", normal: trimNormal(data.shortFuelTrimPct))
            readingRow("Long fuel trim", data.longFuelTrimPct, "%", expected: "Near 0%; usually within ±10%", normal: trimNormal(data.longFuelTrimPct))
            readingRow("Engine load", data.loadPct, "%", expected: "Varies with operating condition", normal: nil)
            readingRow("Throttle opening", data.throttlePct, "%", expected: "Varies with pedal/load", normal: nil)
            readingRow("Intake-air temperature", data.intakeAirF, "°F", expected: "Depends on ambient/heat soak", normal: nil)
        }
        .premiumCard(panel: panel, border: border)
    }

    private var mechanicCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MECHANIC VIEW").font(.caption.bold()).foregroundStyle(.secondary)
            Text("Diagnostic snapshot").font(.title3.bold())

            mechanicLine("VIN", data.vin.isEmpty ? "Not returned" : data.vin)
            mechanicLine("Active DTCs", data.dtcs.isEmpty ? "None" : data.dtcs.joined(separator: ", "))
            mechanicLine("RPM", formatted(data.rpm, suffix: " rpm", digits: 0))
            mechanicLine("Speed", formatted(data.speedMph, suffix: " mph", digits: 1))
            mechanicLine("Coolant", formatted(data.coolantF, suffix: "°F", digits: 0))
            mechanicLine("STFT", formattedSigned(data.shortFuelTrimPct, suffix: "%"))
            mechanicLine("LTFT", formattedSigned(data.longFuelTrimPct, suffix: "%"))
            mechanicLine("System voltage", formatted(data.voltage, suffix: " V", digits: 2))

            if data.dtcs.contains("P200A") {
                Divider().overlay(border)
                Text("Inspection direction").font(.headline)
                Text("Verify intake-manifold runner linkage/actuator movement, connector and wiring integrity, sticking or deposits, then compare commanded versus actual runner position if Hyundai enhanced data exposes those PIDs.")
                    .foregroundStyle(.secondary)
            }
        }
        .premiumCard(panel: panel, border: border)
    }

    private var liveView: some View {
        ScrollView {
            VStack(spacing: 16) {
                header(title: "LIVE DATA", subtitle: "Real standard OBD-II readings supported by the connected car")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    liveTile("Engine speed", formatted(data.rpm, suffix: " rpm", digits: 0), "gauge.with.dots.needle.50percent")
                    liveTile("Speed", formatted(data.speedMph, suffix: " mph", digits: 1), "speedometer")
                    liveTile("Coolant", formatted(data.coolantF, suffix: "°F", digits: 0), "thermometer.medium")
                    liveTile("Voltage", formatted(data.voltage, suffix: " V", digits: 1), "bolt.fill")
                    liveTile("Engine load", formatted(data.loadPct, suffix: "%", digits: 1), "engine.combustion.fill")
                    liveTile("Throttle", formatted(data.throttlePct, suffix: "%", digits: 1), "pedal.accelerator.fill")
                    liveTile("ST fuel trim", formattedSigned(data.shortFuelTrimPct, suffix: "%"), "waveform.path")
                    liveTile("LT fuel trim", formattedSigned(data.longFuelTrimPct, suffix: "%"), "chart.line.uptrend.xyaxis")
                    liveTile("Fuel", formatted(data.fuelPct, suffix: "%", digits: 0), "fuelpump.fill")
                    liveTile("Intake air", formatted(data.intakeAirF, suffix: "°F", digits: 0), "wind")
                }
                if !isConnectedData { emptyState("No live data yet", detail: "Connect the OBDLink CX from Home.") }
            }.padding()
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var settingsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                header(title: "CAR SETTINGS", subtitle: "Detected hardware first. Writes only after we verify Hyundai commands.")

                VStack(alignment: .leading, spacing: 12) {
                    Label("Safety lock is ON", systemImage: "lock.shield.fill").foregroundStyle(green).font(.headline)
                    Text("v0.1 does not write BCM, Smart Key, ABS, SRS, immobilizer, steering, engine or transmission configuration.")
                        .foregroundStyle(.secondary)
                }
                .premiumCard(panel: panel, border: border)

                researchSetting("Automatic door lock", note: "Known Sonata comfort feature • Hyundai write command not verified yet")
                researchSetting("Automatic door unlock", note: "Known Sonata comfort feature • Hyundai write command not verified yet")
                researchSetting("Lock confirmation sound", note: "Known Sonata comfort feature • Hyundai write command not verified yet")
                researchSetting("One-touch turn signal", note: "Known Sonata comfort feature • Hyundai write command not verified yet")
                researchSetting("Headlight delay / welcome lighting", note: "Known Sonata comfort feature • Hyundai write command not verified yet")
                researchSetting("Key-out warning beep", note: "Electronic behavior confirmed • writable configuration still unknown")
            }.padding()
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var vehicleView: some View {
        ScrollView {
            VStack(spacing: 16) {
                header(title: "VEHICLE PROFILE", subtitle: "The adapter decides what exists — not the trim badge")

                VStack(alignment: .leading, spacing: 12) {
                    profileLine("VIN", data.vin.isEmpty ? "Waiting for car" : data.vin, detected: !data.vin.isEmpty)
                    profileLine("Engine / ECM", isConnectedData ? "Responding" : "Not scanned", detected: isConnectedData)
                    profileLine("Standard OBD-II", isConnectedData ? "Available" : "Not scanned", detected: isConnectedData)
                    profileLine("BCM / body electronics", "Enhanced scan planned", detected: false)
                    profileLine("Smart Key", "Enhanced scan planned", detected: false)
                    profileLine("ABS / ESC", "Enhanced scan planned", detected: false)
                    profileLine("SRS / Airbag", "Read-only enhanced scan planned", detected: false)
                    profileLine("TPMS", "Enhanced scan planned", detected: false)
                }
                .premiumCard(panel: panel, border: border)
            }.padding()
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.bold()).tracking(2.0).foregroundStyle(green)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusPill: some View {
        Text(statusPillText)
            .font(.caption.bold())
            .foregroundStyle(isHealthy ? green : amber)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background((isHealthy ? green : amber).opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke((isHealthy ? green : amber).opacity(0.3)))
    }

    private func metricMini(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit())
        }
    }

    private func readingRow(_ title: String, _ value: Double?, _ unit: String, expected: String, normal: Bool?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text("Expected: \(expected)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(value == nil ? "—" : String(format: "%.1f%@", value!, unit)).font(.headline.monospacedDigit())
                if let normal {
                    Text(normal ? "NORMAL" : "CHECK")
                        .font(.caption2.bold()).foregroundStyle(normal ? green : amber)
                } else {
                    Text("CONTEXT").font(.caption2.bold()).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func mechanicLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 20)
            Text(value).multilineTextAlignment(.trailing).monospacedDigit()
        }.font(.subheadline)
    }

    private func liveTile(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon).foregroundStyle(green)
            Text(value).font(.title3.bold().monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .premiumCard(panel: panel, border: border)
    }

    private func emptyState(_ title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "car.circle").font(.system(size: 44)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
        .premiumCard(panel: panel, border: border)
    }

    private func researchSetting(_ title: String, note: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "lock.fill").foregroundStyle(.secondary)
        }
        .premiumCard(panel: panel, border: border)
    }

    private func profileLine(_ title: String, _ detail: String, detected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: detected ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(detected ? green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var isBusy: Bool {
        switch obd.state { case .scanning, .connecting, .connected, .reading: return true; default: return false }
    }
    private var engineRunning: Bool { (data.rpm ?? 0) > 300 }
    private var voltageNormal: Bool? {
        guard let v = data.voltage else { return nil }
        return engineRunning ? (13.2...15.0).contains(v) : (11.8...13.0).contains(v)
    }
    private var coolantNormal: Bool? {
        guard let v = data.coolantF, engineRunning else { return nil }
        return (170...225).contains(v)
    }
    private func trimNormal(_ value: Double?) -> Bool? {
        guard let value else { return nil }
        return abs(value) <= 10
    }
    private var isHealthy: Bool { data.dtcs.isEmpty && isConnectedData }
    private var statusPillText: String {
        if demoMode { return data.dtcs.isEmpty ? "DEMO • GOOD" : "DEMO • ATTENTION" }
        if case .failed = obd.state { return "CONNECTION ISSUE" }
        if obd.state == .finished { return data.dtcs.isEmpty ? "GOOD" : "ATTENTION" }
        return isBusy ? "SCANNING" : "OFFLINE"
    }
    private var homeStatusTitle: String {
        if !isConnectedData { return "Connect your Sonata" }
        return data.dtcs.isEmpty ? "Everything looks good" : "\(data.dtcs.count) thing\(data.dtcs.count == 1 ? "" : "s") needs attention"
    }
    private var connectionMessage: String {
        if demoMode { return "Demo data • no commands sent to a vehicle" }
        return obd.message
    }
    private var connectButtonTitle: String {
        if isBusy { return "Stop" }
        if obd.state == .finished { return "Disconnect" }
        return "Connect Car"
    }
    private var primaryCode: String { data.dtcs.first ?? "" }
    private var primaryPlainTitle: String { plainTitle(for: primaryCode) }
    private var primaryPlainExplanation: String { plainExplanation(for: primaryCode) }

    private func plainTitle(for code: String) -> String {
        switch code {
        case "P200A": return "Engine airflow control isn't moving as expected"
        case "P0562": return "The car's electrical voltage dropped too low"
        default: return "The engine computer found something that needs attention"
        }
    }
    private func plainExplanation(for code: String) -> String {
        switch code {
        case "P200A": return "Part of the intake manifold changes how air enters the engine. The computer expected that mechanism to move differently than it actually did."
        case "P0562": return "The engine computer measured system voltage below the level it expects. The battery, charging system, connections or an electrical load may need checking."
        default: return "The car stored diagnostic code \(code). The mechanic view keeps the original code while the app explains it in normal language."
        }
    }
    private func technicalDefinition(for code: String) -> String {
        switch code {
        case "P200A": return "P200A — Intake Manifold Runner Performance, Bank 1"
        case "P0562": return "P0562 — System Voltage Low"
        default: return "\(code) — definition database expansion pending"
        }
    }
    private func severity(for code: String) -> String {
        switch code { case "P0562": return "CHECK SOON"; default: return "NEEDS ATTENTION" }
    }
    private func symptoms(for code: String) -> String {
        switch code {
        case "P200A": return "Possible hesitation, weaker acceleration under load, reduced fuel economy, or only the check-engine light."
        case "P0562": return "Possible slow starting, dim lights, warning lights, unstable electronics, or stalling if voltage becomes severe."
        default: return "Symptoms depend on the module and operating conditions when the code was stored."
        }
    }

    private func formatted(_ value: Double?, suffix: String, digits: Int) -> String {
        guard let value else { return "—" }
        return String(format: "%.*f%@", digits, value, suffix)
    }
    private func formattedSigned(_ value: Double?, suffix: String) -> String {
        guard let value else { return "—" }
        return String(format: "%+.1f%@", value, suffix)
    }
}

private extension View {
    func premiumCard(panel: Color, border: Color) -> some View {
        self
            .padding(16)
            .background(panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(border, lineWidth: 1))
    }
}

private struct PremiumButtonStyle: ButtonStyle {
    let fill: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .padding(.vertical, 13)
            .padding(.horizontal, 14)
            .background(fill.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PremiumSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(configuration.isPressed ? 0.05 : 0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.12)))
    }
}
