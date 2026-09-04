import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var obd: OBDLinkCXManager
    @State private var filter = "Active"
    let demoMode: Bool
    let scenario: DemoScenario
    private let filters = ["Active", "Pending", "History"]
    private var snapshot: VehicleSnapshot { demoMode ? DemoVehicle.snapshot(for: scenario) : obd.snapshot }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 13) {
                HStack(alignment: .top) {
                    ScreenHeader(title: "Diagnostics", subtitle: "Plain language first. Evidence and mechanic detail when you need it.")
                    HStack(spacing: 4) { Image(systemName: "sparkles"); Text("EXPLAINED") }.font(.system(size: 9, weight: .bold)).foregroundStyle(SDTheme.cyan)
                }
                Picker("Diagnostic status", selection: $filter) { ForEach(filters, id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
                if filter == "Active" {
                    if snapshot.dtcs.isEmpty { emptyActive } else {
                        ForEach(snapshot.dtcs, id: \.self) { code in
                            DiagnosticReferenceCard(record: .record(for: code), snapshot: snapshot, demoMode: demoMode)
                        }
                    }
                } else { unavailableFilter }
            }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

    private var emptyActive: some View {
        VStack(spacing: 10) {
            Image(systemName: snapshot.hasAnyReading ? "checkmark.shield.fill" : "stethoscope").font(.largeTitle).foregroundStyle(snapshot.hasAnyReading ? SDTheme.green : SDTheme.muted)
            Text(snapshot.hasAnyReading ? "No active engine codes" : "Vehicle not scanned").font(.headline)
            Text(snapshot.hasAnyReading ? "The standard engine computer did not return an active DTC." : "Connect from Home to read actual vehicle data.").font(.subheadline).foregroundStyle(SDTheme.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 34).premiumCard(radius: 19)
    }

    private var unavailableFilter: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.badge.questionmark").font(.largeTitle).foregroundStyle(SDTheme.muted)
            Text("\(filter) codes are not available").font(.headline)
            Text("The current read-only scan retrieves active Mode 03 engine DTCs. The app will not label active data as pending or history.").font(.subheadline).foregroundStyle(SDTheme.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 34).premiumCard(radius: 19)
    }
}

private struct DiagnosticReferenceCard: View {
    @EnvironmentObject private var reports: ReportStore
    let record: DiagnosticRecord
    let snapshot: VehicleSnapshot
    let demoMode: Bool
    @State private var section = "Explain"
    @State private var saved = false

    private let sections = ["Explain", "Actual vs Normal", "Mechanic"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.code).font(.system(size: 29, weight: .bold, design: .rounded))
                    Text(record.headline).font(.system(size: 18, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                    Text(record.definition).font(.system(size: 11.5)).foregroundStyle(SDTheme.muted)
                }
                Spacer(minLength: 8)
                StatusBadge(text: "Active", color: record.severity.color)
            }
            HStack(spacing: 7) {
                Circle().fill(record.severity.color).frame(width: 8, height: 8)
                Text("Severity: \(record.severity.rawValue)").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(record.severity.color)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(sections, id: \.self) { item in
                        Button(item) { section = item }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(section == item ? .white : SDTheme.muted)
                            .padding(.horizontal, 13).padding(.vertical, 10)
                            .background(section == item ? Color.white.opacity(0.08) : .clear, in: Capsule())
                            .overlay(Capsule().stroke(SDTheme.border, lineWidth: 0.8))
                    }
                }
            }

            if section == "Explain" {
                Text("What it means").font(.headline)
                Text(record.explanation).font(.system(size: 13)).foregroundStyle(SDTheme.muted).lineSpacing(3)
                DiagnosticCallout(title: "What you might notice", text: record.symptoms.joined(separator: ", ") + ".")
                DiagnosticBulletList(title: "Possible causes", items: record.causes)
            } else if section == "Actual vs Normal" {
                Text("Measurements at scan time").font(.headline)
                DiagnosticValueLine(label: "Battery / Charging", value: formatReading(snapshot.voltage, suffix: " V", digits: 1), note: "Running typically about 13.5–14.8")
                DiagnosticValueLine(label: "Coolant", value: formatReading(snapshot.coolantF, suffix: "°F"), note: "Warm engine typically about 180–220")
                DiagnosticValueLine(label: "Engine load", value: formatReading(snapshot.loadPct, suffix: "%", digits: 0), note: "Condition-dependent")
            } else {
                Text("Mechanic-ready details").font(.headline)
                Text(record.inspection).font(.system(size: 13)).foregroundStyle(SDTheme.muted).lineSpacing(3)
                DiagnosticValueLine(label: "Source module", value: "Engine / ECM", note: "Standard OBD-II Mode 03")
                DiagnosticValueLine(label: "VIN", value: snapshot.vin.isEmpty ? "Not available" : snapshot.vin, note: "Read from connected vehicle")
            }

            HStack(spacing: 10) {
                Button(saved ? "Report Saved" : "Save Report") {
                    reports.save(snapshot: snapshot, demo: demoMode); saved = true
                }.buttonStyle(WhiteButtonStyle())
                Button("Clear") { }.font(.system(size: 14, weight: .semibold)).foregroundStyle(SDTheme.muted)
                    .padding(.horizontal, 20).frame(height: 50).background(SDTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14)).disabled(true)
            }
        }.premiumCard(padding: 16, radius: 19)
    }
}

private struct DiagnosticCallout: View {
    let title: String, text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 15, weight: .bold))
            Text(text).font(.system(size: 13)).foregroundStyle(SDTheme.muted).lineSpacing(3)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(SDTheme.border, lineWidth: 0.7))
    }
}

private struct DiagnosticBulletList: View {
    let title: String, items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) { Circle().fill(SDTheme.muted).frame(width: 4, height: 4).padding(.top, 7); Text(item).font(.system(size: 13)).foregroundStyle(SDTheme.muted) }
            }
        }
    }
}

private struct DiagnosticValueLine: View {
    let label: String, value: String, note: String
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) { Text(label).font(.system(size: 14, weight: .semibold)); Text(note).font(.system(size: 11)).foregroundStyle(SDTheme.muted) }
            Spacer(); Text(value).font(.system(size: 14, weight: .bold).monospacedDigit()).multilineTextAlignment(.trailing)
        }.padding(.vertical, 8).overlay(alignment: .bottom) { Rectangle().fill(SDTheme.border).frame(height: 0.7) }
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
