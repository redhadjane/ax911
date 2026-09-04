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
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 7) {
                        Circle().fill(hasIssue ? SDTheme.amber : SDTheme.green).frame(width: 7, height: 7).shadow(color: (hasIssue ? SDTheme.amber : SDTheme.green).opacity(0.6), radius: 5)
                        Text(hasIssue ? "1 finding needs attention" : "All scanned systems look good")
                            .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(hasIssue ? SDTheme.amber : SDTheme.green)
                    }
                    Spacer()
                    HStack(spacing: 5) { Image(systemName: "sparkles"); Text("SMART SCAN") }
                        .font(.system(size: 9, weight: .bold)).tracking(0.7).foregroundStyle(SDTheme.cyan)
                }

                ZStack {
                    Ellipse().fill(SDTheme.green.opacity(0.045)).frame(width: 300, height: 86).blur(radius: 20).offset(y: 30)
                    Ellipse().stroke(SDTheme.border, lineWidth: 0.7).frame(width: 340, height: 118).offset(y: 30)
                    VehicleRenderView(angle: .hero).frame(maxWidth: .infinity).frame(height: 155)
                    VStack(spacing: 0) {
                        Text(healthScore).font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                        Text("HEALTH").font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle(SDTheme.muted)
                    }
                    .padding(10).background(.black.opacity(0.45), in: Circle()).overlay(Circle().stroke(hasIssue ? SDTheme.amber.opacity(0.4) : SDTheme.green.opacity(0.4), lineWidth: 1))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(.top, 8)
                }.frame(height: 157)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    SystemHealthCard(name: "Engine", detail: snapshot.rpm == 0 ? "Not running" : "Running", state: .detected)
                    SystemHealthCard(name: "Transmission", detail: demoMode ? "No issues" : "Not scanned", state: demoMode ? .detected : .unavailable)
                    SystemHealthCard(name: "Electrical", detail: lowVoltage ? "Low voltage" : "No issues", state: .detected, warning: lowVoltage)
                    SystemHealthCard(name: "Emissions", detail: hasIssue ? "Review finding" : "7 / 10 ready", state: .detected, warning: hasIssue)
                    SystemHealthCard(name: "Intake System", detail: intakeIssue ? "Issue detected" : "No issues", state: .detected, warning: intakeIssue)
                    SystemHealthCard(name: "ABS", detail: demoMode ? "No issues" : "Not scanned", state: demoMode ? .detected : .unavailable)
                }

                SectionLabel(text: "Live telemetry")
                HStack(spacing: 8) {
                    OverviewMetricChip(label: "RPM", value: formatReading(snapshot.rpm, suffix: "", digits: 0), unit: "rpm")
                    OverviewMetricChip(label: "Coolant", value: formatReading(snapshot.coolantF, suffix: "", digits: 0), unit: "°F")
                    OverviewMetricChip(label: "Speed", value: formatReading(snapshot.speedMph, suffix: "", digits: 0), unit: "mph")
                    OverviewMetricChip(label: "Battery", value: formatReading(snapshot.voltage, suffix: "", digits: 1), unit: "V")
                }
                .frame(maxWidth: .infinity)

                Button(action: onOpenDiagnostics) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) { Image(systemName: "sparkles"); Text("INTELLIGENCE SUMMARY") }
                                .font(.system(size: 9.5, weight: .bold)).tracking(1.1).foregroundStyle(hasIssue ? SDTheme.amber : SDTheme.green)
                            Text(hasIssue ? intelligenceHeadline : "Your Sonata looks stable").font(.system(size: 15.5, weight: .bold)).foregroundStyle(.white)
                            Text(hasIssue ? "See the plain-English explanation, actual readings and mechanic details." : "The current scan did not return an active engine code.")
                                .font(.system(size: 11.5)).foregroundStyle(SDTheme.muted).multilineTextAlignment(.leading).lineLimit(2)
                        }
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(SDTheme.muted)
                    }
                    .premiumCard(padding: 15, radius: 18)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SDTheme.background)
    }

    private var intakeIssue: Bool { snapshot.dtcs.contains("P200A") }
    private var lowVoltage: Bool { snapshot.dtcs.contains("P0562") || (snapshot.voltage ?? 13) < 12.2 }
    private var healthScore: String { hasIssue ? (lowVoltage ? "72" : "84") : "96" }
    private var intelligenceHeadline: String { lowVoltage ? "Charging voltage needs priority" : "Review the intake-system finding" }
}

private struct OverviewMetricChip: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 5) {
            Text(label).font(.system(size: 9.5, weight: .medium)).foregroundStyle(SDTheme.muted).lineLimit(1).minimumScaleFactor(0.72)
            Text(value).font(.system(size: 18, weight: .bold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.62)
            Text(unit).font(.system(size: 9, weight: .medium)).foregroundStyle(SDTheme.muted)
        }
        .frame(maxWidth: .infinity).frame(height: 74)
        .background(SDTheme.panel, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(SDTheme.border, lineWidth: 0.8))
    }
}
