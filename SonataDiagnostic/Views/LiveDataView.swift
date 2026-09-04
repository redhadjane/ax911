import SwiftUI

struct LiveDataView: View {
    @EnvironmentObject private var obd: OBDLinkCXManager
    let demoMode: Bool
    let scenario: DemoScenario
    @State private var category = "All"
    private let categories = ["All", "Engine", "Fuel", "Sensors"]
    private var snapshot: VehicleSnapshot { demoMode ? DemoVehicle.snapshot(for: scenario) : obd.snapshot }

    var body: some View {
        ScrollView {
            VStack(spacing: 13) {
                HStack(alignment: .top) {
                    ScreenHeader(title: "Live telemetry", subtitle: "Current values, useful context, and anomaly-aware traces.")
                    StatusBadge(text: "LIVE", color: SDTheme.green)
                }
                categoryBar
                if rows.isEmpty { emptyState } else {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.title) { index, row in
                            LiveReadingRow(row: row, demoMode: demoMode)
                            if index < rows.count - 1 { Divider().overlay(SDTheme.border) }
                        }
                    }.premiumCard(padding: 0, radius: 19)
                }
                Text(demoMode ? "Demo telemetry is simulated for interface preview." : "Only values returned by the vehicle are shown. No readings are synthesized.").font(.system(size: 11)).foregroundStyle(SDTheme.muted).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

    private var categoryBar: some View {
        HStack(spacing: 6) {
            ForEach(categories, id: \.self) { item in
                Button(item) { withAnimation(.easeOut(duration: 0.15)) { category = item } }
                    .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(category == item ? .black : SDTheme.muted)
                    .frame(maxWidth: .infinity).frame(height: 38).background(category == item ? Color.white : Color.clear, in: Capsule())
            }
        }.padding(3).background(SDTheme.panel, in: Capsule()).overlay(Capsule().stroke(SDTheme.border, lineWidth: 0.7))
    }

    private var rows: [LiveReading] {
        var result: [LiveReading] = []
        func add(_ title: String, _ value: Double?, _ rendered: String, _ group: String, _ reference: String, _ outside: Bool, _ demo: [Double]) {
            guard value != nil, category == "All" || category == group else { return }
            result.append(LiveReading(title: title, value: rendered, reference: reference, color: outside ? SDTheme.amber : SDTheme.green, outside: outside, demoValues: demo))
        }
        add("Engine RPM", snapshot.rpm, formatReading(snapshot.rpm, suffix: " rpm"), "Engine", "Warm idle typically 650–900", false, [780, 792, 786, 806, 794, 800])
        add("Vehicle Speed", snapshot.speedMph, formatReading(snapshot.speedMph, suffix: " mph", digits: 0), "Engine", "Wheel / vehicle-speed signal", false, [0, 0, 0, 0, 0])
        add("Coolant Temperature", snapshot.coolantF, formatReading(snapshot.coolantF, suffix: "°F"), "Sensors", "Warm engine typically 180–220", (snapshot.coolantF ?? 190) > 220, [190, 191, 192, 193, 194])
        add("Battery / Charging", snapshot.voltage, formatReading(snapshot.voltage, suffix: " V", digits: 1), "Sensors", "Running typically 13.5–14.8", (snapshot.rpm ?? 0) > 0 && (snapshot.voltage ?? 14) < 13.5, [14.0, 14.1, 14.0, 14.2, 14.1])
        add("Intake Air Temperature", snapshot.intakeAirF, formatReading(snapshot.intakeAirF, suffix: "°F"), "Sensors", "Depends on ambient and heat soak", false, [81, 82, 82, 83, 82])
        add("Short-Term Fuel Trim B1", snapshot.shortFuelTrimPct, signedReading(snapshot.shortFuelTrimPct, suffix: "%"), "Fuel", "Typical reference: −10 to +10", abs(snapshot.shortFuelTrimPct ?? 0) > 10, [10.8, 11.2, 10.9, 11.7, 11.8])
        add("Long-Term Fuel Trim B1", snapshot.longFuelTrimPct, signedReading(snapshot.longFuelTrimPct, suffix: "%"), "Fuel", "Typical reference: −10 to +10", abs(snapshot.longFuelTrimPct ?? 0) > 10, [7.1, 7.3, 7.5, 7.3, 7.4])
        add("Calculated Engine Load", snapshot.loadPct, formatReading(snapshot.loadPct, suffix: "%", digits: 0), "Engine", "Condition-dependent", false, [18, 19, 21, 20, 21])
        add("Throttle Position", snapshot.throttlePct, formatReading(snapshot.throttlePct, suffix: "%", digits: 1), "Engine", "Changes with load and driver input", false, [10, 11, 10.5, 12, 11.4])
        add("Fuel Level", snapshot.fuelPct, formatReading(snapshot.fuelPct, suffix: "%"), "Fuel", "Vehicle-reported estimate", false, [62, 62, 62, 62])
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

private struct LiveReading { let title: String; let value: String; let reference: String; let color: Color; let outside: Bool; let demoValues: [Double] }

private struct LiveReadingRow: View {
    let row: LiveReading
    let demoMode: Bool
    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title).font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    Text(row.reference).font(.system(size: 10.5)).foregroundStyle(SDTheme.muted).lineLimit(1).minimumScaleFactor(0.82)
                }
                Spacer()
                Text(row.value).font(.system(size: 16.5, weight: .bold).monospacedDigit()).foregroundStyle(.white).lineLimit(1)
            }
            HStack {
                Text(row.outside ? "Outside reference" : "Within context").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(row.color)
                Spacer()
                LiveGraph(values: demoMode ? row.demoValues : nil, color: row.color).frame(width: 130, height: 28)
            }
        }.padding(.horizontal, 15).padding(.vertical, 13)
    }
}
