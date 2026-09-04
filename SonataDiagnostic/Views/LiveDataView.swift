import SwiftUI

struct LiveDataView: View {
    @EnvironmentObject private var obd: OBDLinkCXManager
    let demoMode: Bool
    @State private var category = "All"
    private let categories = ["All", "Engine", "Fuel", "Sensors"]
    private var snapshot: VehicleSnapshot { demoMode ? DemoVehicle.snapshot : obd.snapshot }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack { ScreenHeader(title: "Live Data", subtitle: "Supported standard OBD-II readings"); if demoMode { StatusBadge(text: "DEMO", color: SDTheme.amber) } }
                categoryBar
                if rows.isEmpty { emptyState } else {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.title) { index, row in
                            LiveReadingRow(row: row, demoMode: demoMode)
                            if index < rows.count - 1 { Divider().overlay(SDTheme.border) }
                        }
                    }.premiumCard(padding: 0)
                }
                Text(demoMode ? "Sample traces are labeled Demo Mode." : "Values are shown only when returned by the connected vehicle. Historical traces require a live streaming session and are never synthesized.").font(.caption).foregroundStyle(SDTheme.muted).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
        }
        .background(SDTheme.background).navigationBarHidden(true)
    }

    private var categoryBar: some View {
        HStack(spacing: 4) {
            ForEach(categories, id: \.self) { item in
                Button(item) { category = item }.font(.system(size: 13, weight: .semibold)).foregroundStyle(category == item ? .black : SDTheme.muted).frame(maxWidth: .infinity).padding(.vertical, 10).background(category == item ? Color.white : Color.clear, in: Capsule())
            }
        }.padding(4).background(SDTheme.panel, in: Capsule()).overlay(Capsule().stroke(SDTheme.border, lineWidth: 0.7))
    }

    private var rows: [LiveReading] {
        var result: [LiveReading] = []
        func add(_ title: String, _ value: Double?, _ rendered: String, _ group: String, _ color: Color, _ demo: [Double]) {
            guard value != nil, category == "All" || category == group else { return }
            result.append(LiveReading(title: title, value: rendered, color: color, demoValues: demo))
        }
        add("Engine RPM", snapshot.rpm, formatReading(snapshot.rpm, suffix: " rpm"), "Engine", SDTheme.green, [720, 735, 728, 760, 745, 798])
        add("Vehicle Speed", snapshot.speedMph, formatReading(snapshot.speedMph, suffix: " mph", digits: 1), "Engine", SDTheme.green, [0, 0, 0, 0, 0])
        add("Coolant Temperature", snapshot.coolantF, formatReading(snapshot.coolantF, suffix: "°F"), "Sensors", SDTheme.amber, [190, 191, 192, 193, 194])
        add("Intake Air Temperature", snapshot.intakeAirF, formatReading(snapshot.intakeAirF, suffix: "°F"), "Sensors", SDTheme.amber, [81, 82, 82, 83, 82])
        add("Short Fuel Trim B1", snapshot.shortFuelTrimPct, signedReading(snapshot.shortFuelTrimPct, suffix: "%"), "Fuel", SDTheme.green, [1.1, 2.8, 1.9, 3.0, 2.3])
        add("Long Fuel Trim B1", snapshot.longFuelTrimPct, signedReading(snapshot.longFuelTrimPct, suffix: "%"), "Fuel", SDTheme.green, [2.7, 2.9, 3.1, 3.0, 3.1])
        add("Calculated Engine Load", snapshot.loadPct, formatReading(snapshot.loadPct, suffix: "%", digits: 1), "Engine", SDTheme.green, [18, 19, 21, 20, 21])
        add("Throttle Position", snapshot.throttlePct, formatReading(snapshot.throttlePct, suffix: "%", digits: 1), "Engine", SDTheme.green, [10, 11, 10.5, 12, 11.4])
        add("Control Module Voltage", snapshot.voltage, formatReading(snapshot.voltage, suffix: " V", digits: 1), "Sensors", SDTheme.green, [12.3, 12.4, 12.4, 12.4])
        add("Fuel Level", snapshot.fuelPct, formatReading(snapshot.fuelPct, suffix: "%"), "Fuel", SDTheme.green, [62, 62, 62, 62])
        return result
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg").font(.largeTitle).foregroundStyle(SDTheme.muted)
            Text("No supported readings yet").font(.headline)
            Text("Connect the OBDLink CX from Home. Real Mode never substitutes demo values.").font(.subheadline).foregroundStyle(SDTheme.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 42).premiumCard()
    }
}

private struct LiveReading { let title: String; let value: String; let color: Color; let demoValues: [Double] }

private struct LiveReadingRow: View {
    let row: LiveReading
    let demoMode: Bool
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) { Text(row.title).font(.system(size: 16, weight: .medium)); Text(row.value).font(.system(size: 19, weight: .semibold, design: .monospaced)).foregroundStyle(.white) }
            Spacer()
            LiveGraph(values: demoMode ? row.demoValues : nil, color: row.color).frame(width: 120, height: 42)
        }.padding(.horizontal, 16).padding(.vertical, 15)
    }
}
