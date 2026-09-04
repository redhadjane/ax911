import SwiftUI

struct DiagnosticDetailView: View {
    @EnvironmentObject private var reports: ReportStore
    let record: DiagnosticRecord
    let snapshot: VehicleSnapshot
    let demoMode: Bool
    @State private var level = "Explain to Me"
    @State private var saved = false
    private let levels = ["Explain to Me", "Readings", "Mechanic Details"]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text(record.code).font(.largeTitle.monospaced().weight(.semibold)); Spacer(); StatusBadge(text: "ACTIVE", color: record.severity.color) }
                    Text(record.definition).font(.subheadline).foregroundStyle(SDTheme.muted)
                    HStack(spacing: 6) { Circle().fill(record.severity.color).frame(width: 6, height: 6); Text("Severity: \(record.severity.rawValue)").font(.caption).foregroundStyle(record.severity.color) }
                }.premiumCard()
                levelBar
                if level == "Readings" { readings } else if level == "Mechanic Details" { mechanicDetails } else { explanation }
                HStack(spacing: 10) {
                    Button("Clear Code") { }.font(.subheadline.weight(.semibold)).foregroundStyle(SDTheme.muted).frame(maxWidth: .infinity).padding(.vertical, 12).background(SDTheme.panel, in: RoundedRectangle(cornerRadius: 13)).disabled(true)
                    Button(saved ? "Report Saved" : "Save Report") { reports.save(snapshot: snapshot, demo: demoMode); saved = true }.buttonStyle(WhiteButtonStyle())
                }
            }.padding(16)
        }
        .background(SDTheme.background).navigationTitle("Diagnostic Detail").navigationBarTitleDisplayMode(.inline)
    }

    private var levelBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(levels, id: \.self) { item in
                    Button(item) { level = item }.font(.caption.weight(.semibold)).foregroundStyle(level == item ? .black : SDTheme.muted).padding(.horizontal, 12).padding(.vertical, 8).background(level == item ? Color.white : SDTheme.panel, in: Capsule())
                }
            }
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(record.headline).font(.title2.weight(.semibold))
            Text(record.explanation).foregroundStyle(SDTheme.muted)
            DetailList(title: "What you may notice", items: record.symptoms)
            DetailList(title: "Possible causes", items: record.causes)
        }.frame(maxWidth: .infinity, alignment: .leading).premiumCard()
    }

    private var readings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Measurements at scan time").font(.headline)
            Text("Expected values change with temperature, engine state, load, and vehicle speed.").font(.caption).foregroundStyle(SDTheme.muted)
            DiagnosticReadingRow(measurement: "Runner position", actual: "Not available from this vehicle", expected: "Requires verified commanded/actual enhanced PIDs", difference: "Not available", state: "Unavailable", color: SDTheme.muted)
            DiagnosticReadingRow(measurement: "Charging voltage", actual: formatReading(snapshot.voltage, suffix: " V", digits: 1), expected: engineRunning ? "13.5–14.8 V, engine running" : "~12.4–12.8 V, engine off", difference: "Context dependent", state: voltageState, color: voltageColor)
            DiagnosticReadingRow(measurement: "Coolant", actual: formatReading(snapshot.coolantF, suffix: "°F"), expected: engineWarm ? "~185–220°F, warm engine" : "Near ambient while cold", difference: "Context dependent", state: coolantState, color: coolantColor)
            DiagnosticReadingRow(measurement: "Engine load", actual: formatReading(snapshot.loadPct, suffix: "%", digits: 1), expected: "Varies with idle/load", difference: "No universal delta", state: snapshot.loadPct == nil ? "Unavailable" : "Context needed", color: SDTheme.muted)
        }.premiumCard()
    }

    private var mechanicDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            mechanicLine("DTC", record.code)
            mechanicLine("Source module", "Engine / ECM (standard OBD-II)")
            mechanicLine("Status", "Active / confirmed Mode 03")
            mechanicLine("Occurrence count", "Not available from this vehicle")
            mechanicLine("Freeze-frame", "Not queried in the current read-only scan")
            mechanicLine("Runner PID IDs", "Not available; enhanced Hyundai PID not verified")
            mechanicLine("VIN", snapshot.vin.isEmpty ? "Not available from this vehicle" : snapshot.vin)
            Divider().overlay(SDTheme.border)
            Text("Technical definition").font(.headline)
            Text(record.definition).font(.subheadline.monospaced()).foregroundStyle(SDTheme.muted)
            Text("Inspection direction").font(.headline)
            Text(record.inspection).foregroundStyle(SDTheme.muted)
        }.premiumCard()
    }

    private var engineRunning: Bool { (snapshot.rpm ?? 0) > 0 }
    private var engineWarm: Bool { (snapshot.coolantF ?? 0) >= 160 }
    private var voltageState: String {
        guard let value = snapshot.voltage else { return "Unavailable" }
        return engineRunning ? (value >= 13.5 && value <= 14.8 ? "Normal" : value < 13.5 ? "Low" : "High") : (value >= 12.2 && value <= 12.9 ? "Normal" : value < 12.2 ? "Low" : "High")
    }
    private var voltageColor: Color { voltageState == "Normal" ? SDTheme.green : voltageState == "Unavailable" ? SDTheme.muted : SDTheme.amber }
    private var coolantState: String {
        guard let value = snapshot.coolantF else { return "Unavailable" }
        if engineWarm { return value <= 220 ? "Normal" : "High" }
        return "Cold / warming"
    }
    private var coolantColor: Color { coolantState == "Normal" ? SDTheme.green : coolantState == "Unavailable" ? SDTheme.muted : SDTheme.amber }
    private func mechanicLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) { Text(label).font(.caption).foregroundStyle(SDTheme.muted).frame(width: 105, alignment: .leading); Text(value).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading) }
    }
}

private struct DetailList: View {
    let title: String
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline)
            ForEach(items, id: \.self) { item in HStack(alignment: .top, spacing: 8) { Circle().fill(SDTheme.muted).frame(width: 4, height: 4).padding(.top, 7); Text(item).font(.subheadline).foregroundStyle(SDTheme.muted) } }
        }
    }
}

private struct DiagnosticReadingRow: View {
    let measurement: String, actual: String, expected: String, difference: String, state: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(measurement).font(.subheadline.weight(.semibold)); Spacer(); StatusBadge(text: state, color: color) }
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 5) {
                GridRow { label("Actual"); value(actual) }
                GridRow { label("Expected"); value(expected) }
                GridRow { label("Difference"); value(difference) }
            }
        }.padding(.vertical, 7).overlay(alignment: .bottom) { Rectangle().fill(SDTheme.border).frame(height: 0.6) }
    }
    private func label(_ text: String) -> some View { Text(text).font(.caption).foregroundStyle(SDTheme.muted).frame(width: 68, alignment: .leading) }
    private func value(_ text: String) -> some View { Text(text).font(.caption).frame(maxWidth: .infinity, alignment: .leading) }
}
