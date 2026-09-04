import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var obd: OBDLinkCXManager
    let demoMode: Bool
    let scenario: DemoScenario
    let onOpenDiagnostics: () -> Void

    private var snapshot: VehicleSnapshot { demoMode ? DemoVehicle.snapshot(for: scenario) : obd.snapshot }
    private var hasIssue: Bool { !snapshot.dtcs.isEmpty }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 7) {
                    Circle().fill(hasIssue ? SDTheme.amber : SDTheme.green).frame(width: 7, height: 7)
                    Text(hasIssue ? "1 issue needs attention" : "All scanned systems look good")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(hasIssue ? SDTheme.amber : SDTheme.green)
                }

                VehicleRenderView(angle: .hero).frame(maxWidth: .infinity).frame(height: 168)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    SystemHealthCard(name: "Engine", detail: snapshot.rpm == 0 ? "Not running" : "Running", state: .detected)
                    SystemHealthCard(name: "Transmission", detail: demoMode ? "No issues" : "Not scanned", state: demoMode ? .detected : .unavailable)
                    SystemHealthCard(name: "Electrical", detail: lowVoltage ? "Low voltage" : "No issues", state: .detected, warning: lowVoltage)
                    SystemHealthCard(name: "Emissions", detail: hasIssue ? "Review finding" : "7 / 10 ready", state: .detected, warning: hasIssue)
                    SystemHealthCard(name: "Intake System", detail: intakeIssue ? "Issue detected" : "No issues", state: .detected, warning: intakeIssue)
                    SystemHealthCard(name: "ABS", detail: demoMode ? "No issues" : "Not scanned", state: demoMode ? .detected : .unavailable)
                }

                SectionLabel(text: "Live Data · Selected")
                HStack(spacing: 9) {
                    OverviewMetricChip(label: "RPM", value: formatReading(snapshot.rpm, suffix: "", digits: 0), unit: "rpm")
                    OverviewMetricChip(label: "Coolant", value: formatReading(snapshot.coolantF, suffix: "", digits: 0), unit: "°F")
                    OverviewMetricChip(label: "Speed", value: formatReading(snapshot.speedMph, suffix: "", digits: 0), unit: "mph")
                    OverviewMetricChip(label: "Battery", value: formatReading(snapshot.voltage, suffix: "", digits: 1), unit: "V")
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 6) {
                    Spacer(); Circle().fill(Color.white.opacity(0.65)).frame(width: 6, height: 6); Circle().fill(Color.white.opacity(0.18)).frame(width: 6, height: 6); Spacer()
                }

                Button(action: onOpenDiagnostics) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("RECOMMENDED NEXT STEP").font(.system(size: 10, weight: .bold)).tracking(1.4).foregroundStyle(SDTheme.amber)
                            Text(hasIssue ? "Review the diagnostic finding" : "Review your live readings").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            Text(hasIssue ? "See the plain-English explanation, actual readings and mechanic details." : "The current scan did not return an active engine code.")
                                .font(.system(size: 12)).foregroundStyle(SDTheme.muted).multilineTextAlignment(.leading)
                        }
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(SDTheme.muted)
                    }
                    .premiumCard(padding: 16)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SDTheme.background)
    }

    private var intakeIssue: Bool { snapshot.dtcs.contains("P200A") }
    private var lowVoltage: Bool { snapshot.dtcs.contains("P0562") || (snapshot.voltage ?? 13) < 12.2 }
}

private struct OverviewMetricChip: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 5) {
            Text(label).font(.system(size: 11)).foregroundStyle(SDTheme.muted).lineLimit(1).minimumScaleFactor(0.7)
            Text(value).font(.system(size: 20, weight: .bold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.6)
            Text(unit).font(.system(size: 10, weight: .medium)).foregroundStyle(SDTheme.muted)
        }
        .frame(maxWidth: .infinity).frame(height: 92)
        .background(SDTheme.panel, in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(SDTheme.border, lineWidth: 0.8))
    }
}
