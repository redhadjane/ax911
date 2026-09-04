import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var reports: ReportStore
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if reports.reports.isEmpty {
                    VStack(spacing: 9) {
                        Image(systemName: "doc.text").font(.largeTitle).foregroundStyle(SDTheme.muted)
                        Text("No saved reports").font(.headline)
                        Text("Open an active diagnostic and choose Save Report.").font(.subheadline).foregroundStyle(SDTheme.muted)
                    }.frame(maxWidth: .infinity).padding(.vertical, 40).premiumCard()
                } else {
                    ForEach(reports.reports) { report in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Text("Diagnostics Report").font(.headline); Spacer(); if report.demo { StatusBadge(text: "DEMO", color: SDTheme.amber) } }
                            Text(report.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(SDTheme.muted)
                            reportLine("Vehicle", report.vin.isEmpty ? "VIN not available" : report.vin)
                            reportLine("Active codes", report.codes.isEmpty ? "None" : report.codes.joined(separator: ", "))
                            reportLine("RPM", formatReading(report.rpm, suffix: " rpm"))
                            reportLine("Coolant", formatReading(report.coolantF, suffix: "°F"))
                            reportLine("Voltage", formatReading(report.voltage, suffix: " V", digits: 1))
                        }.premiumCard()
                    }
                }
            }.padding(16)
        }
        .background(SDTheme.background).navigationTitle("Reports").navigationBarTitleDisplayMode(.inline)
    }
    private func reportLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) { Text(label).font(.caption).foregroundStyle(SDTheme.muted).frame(width: 82, alignment: .leading); Text(value).font(.caption).frame(maxWidth: .infinity, alignment: .leading) }
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                Text("ABOUT THIS APP").font(.title2.bold())
                Text("Sonata Diagnostic is a private, read-only companion for supported Hyundai Sonata LF vehicles and OBDLink CX.")
                Text("It reads standard OBD-II data over Bluetooth. Your vehicle data stays on this iPhone; no account or subscription is required.")
                Text("Hyundai-specific settings remain disabled until their module, command, readback, and safe write behavior are verified.")
                HStack(spacing: 18) { Label("Bluetooth LE", systemImage: "antenna.radiowaves.left.and.right"); Label("OBD-II", systemImage: "car.fill") }.font(.caption).foregroundStyle(SDTheme.muted)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }
        .background(SDTheme.background).navigationTitle("About").navigationBarTitleDisplayMode(.inline)
    }
}
