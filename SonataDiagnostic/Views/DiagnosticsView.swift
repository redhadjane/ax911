import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var obd: OBDLinkCXManager
    @State private var filter = "Active"
    let demoMode: Bool
    private let filters = ["Active", "Pending", "History"]
    private var snapshot: VehicleSnapshot { demoMode ? DemoVehicle.snapshot : obd.snapshot }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack { ScreenHeader(title: "Diagnostics", subtitle: "Plain English first. Technical evidence deeper."); if demoMode { StatusBadge(text: "DEMO", color: SDTheme.amber) } }
                Picker("Diagnostic status", selection: $filter) { ForEach(filters, id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
                if filter == "Active" {
                    if snapshot.dtcs.isEmpty { emptyActive } else {
                        ForEach(snapshot.dtcs, id: \.self) { code in
                            NavigationLink(value: DiagnosticRecord.record(for: code)) { DiagnosticSummaryCard(record: .record(for: code)) }.buttonStyle(.plain)
                        }
                    }
                } else { unavailableFilter }
            }.padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SDTheme.background.ignoresSafeArea()).navigationBarHidden(true)
        .navigationDestination(for: DiagnosticRecord.self) { record in DiagnosticDetailView(record: record, snapshot: snapshot, demoMode: demoMode) }
    }

    private var emptyActive: some View {
        VStack(spacing: 10) {
            Image(systemName: snapshot.hasAnyReading ? "checkmark.shield.fill" : "stethoscope").font(.largeTitle).foregroundStyle(snapshot.hasAnyReading ? SDTheme.green : SDTheme.muted)
            Text(snapshot.hasAnyReading ? "No active engine codes" : "Vehicle not scanned").font(.headline)
            Text(snapshot.hasAnyReading ? "The standard engine computer did not return an active DTC." : "Connect from Home to read actual vehicle data.").font(.subheadline).foregroundStyle(SDTheme.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 38).premiumCard()
    }

    private var unavailableFilter: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.badge.questionmark").font(.largeTitle).foregroundStyle(SDTheme.muted)
            Text("\(filter) codes are not available").font(.headline)
            Text("The current read-only scan retrieves active Mode 03 engine DTCs. The app will not label active data as pending or history.").font(.subheadline).foregroundStyle(SDTheme.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 38).premiumCard()
    }
}

private struct DiagnosticSummaryCard: View {
    let record: DiagnosticRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack { StatusBadge(text: "ACTIVE", color: record.severity.color); Spacer(); Text(record.code).font(.subheadline.monospaced().weight(.semibold)).foregroundStyle(SDTheme.muted) }
            Text(record.headline).font(.system(size: 22, weight: .semibold, design: .rounded)).multilineTextAlignment(.leading)
            Text(record.definition).font(.system(size: 15)).foregroundStyle(SDTheme.muted).multilineTextAlignment(.leading)
            HStack { Circle().fill(record.severity.color).frame(width: 6, height: 6); Text("Severity: \(record.severity.rawValue)").font(.caption).foregroundStyle(record.severity.color); Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(SDTheme.muted) }
        }.premiumCard()
    }
}
