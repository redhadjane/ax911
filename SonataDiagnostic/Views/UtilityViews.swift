import SwiftUI

struct MaintenanceView: View {
    let demoMode: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Maintenance", subtitle: "Simple service tracking that stays on this iPhone.")
                SectionLabel(text: "Upcoming")
                MaintenanceCard(icon: "drop.fill", title: "Engine oil & filter", detail: demoMode ? "Due in 1,460 mi" : "Add your last service to calculate", accent: SDTheme.green)
                MaintenanceCard(icon: "arrow.triangle.2.circlepath", title: "Tire rotation", detail: demoMode ? "Due in 2,100 mi" : "No service history yet", accent: SDTheme.muted)
                MaintenanceCard(icon: "wind", title: "Cabin air filter", detail: demoMode ? "Inspect at next service" : "No service history yet", accent: SDTheme.muted)
                Text(demoMode ? "Demo intervals are illustrative and are not service recommendations." : "No maintenance values are inferred from OBD data. Add records only when you have the actual service information.")
                    .font(.caption).foregroundStyle(SDTheme.muted).padding(.top, 4)
            }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 18)
        }.background(Color.clear)
    }
}

private struct MaintenanceCard: View {
    let icon: String, title: String, detail: String
    let accent: Color
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 13).fill(accent.opacity(0.12)).frame(width: 48, height: 48).overlay(Image(systemName: icon).foregroundStyle(accent))
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 16, weight: .bold)); Text(detail).font(.system(size: 13)).foregroundStyle(SDTheme.muted) }
            Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(SDTheme.muted)
        }.premiumCard(padding: 15)
    }
}

struct DataLoggingView: View {
    let demoMode: Bool
    @State private var logging = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Data Logging", subtitle: "Capture supported live readings for review after a drive.")
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(logging ? "Recording demo session" : "Ready to record").font(.system(size: 18, weight: .bold))
                            Text(logging ? "00:00:18 · 9 channels" : "RPM, speed, temperatures, fuel trims and voltage").font(.system(size: 13)).foregroundStyle(SDTheme.muted)
                        }
                        Spacer(); Circle().fill(logging ? SDTheme.red : SDTheme.green).frame(width: 10, height: 10)
                    }
                    Button(logging ? "Stop Demo Recording" : "Start Demo Recording") { logging.toggle() }
                        .buttonStyle(WhiteButtonStyle()).disabled(!demoMode)
                    if !demoMode {
                        Text("Live logging will be enabled only after stream timing and export integrity are verified with a connected vehicle.")
                            .font(.caption).foregroundStyle(SDTheme.muted)
                    }
                }.premiumCard()
                SectionLabel(text: "Saved drives")
                Text("No recordings yet").font(.system(size: 15, weight: .medium)).foregroundStyle(SDTheme.muted).frame(maxWidth: .infinity).padding(.vertical, 34).premiumCard()
            }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 18)
        }.background(Color.clear)
    }
}

struct VehicleProfileView: View {
    @EnvironmentObject private var obd: OBDLinkCXManager
    let demoMode: Bool
    let scenario: DemoScenario
    private var snapshot: VehicleSnapshot { demoMode ? DemoVehicle.snapshot(for: scenario) : obd.snapshot }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Vehicle Profile", subtitle: "The adapter decides what exists — not the trim badge.")
                VStack(spacing: 0) {
                    ProfileRow(title: "VIN", detail: snapshot.vin.isEmpty ? "Waiting for car" : snapshot.vin, available: !snapshot.vin.isEmpty)
                    ProfileRow(title: "Engine / ECM", detail: snapshot.hasAnyReading ? "Standard OBD response" : "Not scanned", available: snapshot.hasAnyReading)
                    ProfileRow(title: "Standard OBD-II", detail: snapshot.hasAnyReading ? "Read-only diagnostics" : "Not scanned", available: snapshot.hasAnyReading)
                    ProfileRow(title: "BCM / body electronics", detail: "Enhanced scan planned", available: false)
                    ProfileRow(title: "Smart Key", detail: "Enhanced scan planned", available: false)
                    ProfileRow(title: "ABS / ESC", detail: "Enhanced scan planned", available: false)
                    ProfileRow(title: "SRS / Airbag", detail: "Protected system", available: false)
                }.premiumCard(padding: 0)
                Text("Unsupported modules stay unavailable. Sonata Diagnostic does not guess capabilities or send experimental write commands.")
                    .font(.caption).foregroundStyle(SDTheme.muted)
            }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 18)
        }.background(Color.clear)
    }
}

private struct ProfileRow: View {
    let title: String, detail: String
    let available: Bool
    var body: some View {
        HStack(spacing: 14) {
            Circle().stroke(available ? SDTheme.green : SDTheme.muted, lineWidth: 1.5).frame(width: 22, height: 22)
                .overlay(Circle().fill(available ? SDTheme.green : .clear).frame(width: 9, height: 9))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 17, weight: .bold))
                Text(detail).font(.system(size: 13)).foregroundStyle(SDTheme.muted)
            }
            Spacer()
        }.padding(.horizontal, 18).padding(.vertical, 16).overlay(alignment: .bottom) { Rectangle().fill(SDTheme.border).frame(height: 0.7) }
    }
}
