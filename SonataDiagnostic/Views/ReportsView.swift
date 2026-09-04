import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var reports: ReportStore
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 13) {
                HStack(alignment: .top) {
                    ScreenHeader(title: "Reports", subtitle: "Private scan summaries saved only on this iPhone.")
                    StatusBadge(text: "LOCAL", color: SDTheme.green)
                }
                if reports.reports.isEmpty {
                    VStack(spacing: 9) {
                        Image(systemName: "doc.text").font(.largeTitle).foregroundStyle(SDTheme.muted)
                        Text("No saved reports").font(.headline)
                        Text("Open an active diagnostic and choose Save Report.").font(.subheadline).foregroundStyle(SDTheme.muted)
                    }.frame(maxWidth: .infinity).padding(.vertical, 38).premiumCard(radius: 19)
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
                        }.premiumCard(radius: 19)
                    }
                }
            }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 18)
        }
        .background(Color.clear)
    }
    private func reportLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) { Text(label).font(.system(size: 13)).foregroundStyle(SDTheme.muted).frame(width: 92, alignment: .leading); Text(value).font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading) }
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 15) {
                ScreenHeader(title: "About", subtitle: "A calmer, private way to understand your Sonata.")
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 14).fill(SDTheme.green.opacity(0.12)).frame(width: 52, height: 52).overlay(Image(systemName: "waveform.path.ecg").font(.system(size: 22, weight: .semibold)).foregroundStyle(SDTheme.green))
                        VStack(alignment: .leading, spacing: 3) { Text("Sonata Diagnostic").font(.system(size: 17, weight: .bold)); Text("Version 1.0 · 2026 Edition").font(.system(size: 11.5)).foregroundStyle(SDTheme.muted) }
                    }
                    Text("A native, read-only companion for supported Hyundai Sonata LF vehicles and OBDLink CX.").font(.system(size: 13.5)).lineSpacing(3)
                    AboutLine(icon: "lock.shield.fill", title: "Private by design", detail: "Vehicle data stays on this iPhone. No account, cloud upload, or subscription.")
                    AboutLine(icon: "antenna.radiowaves.left.and.right", title: "Direct Bluetooth LE", detail: "Connects locally to OBDLink CX and reads standard OBD-II information.")
                    AboutLine(icon: "checkmark.seal.fill", title: "Honest capabilities", detail: "Unsupported modules and experimental settings remain visibly locked.")
                }.premiumCard(radius: 20)
                Text("Sonata Diagnostic is an independent diagnostic companion and is not affiliated with Hyundai Motor Company or OBD Solutions.").font(.system(size: 10.5)).foregroundStyle(SDTheme.tertiary).lineSpacing(2)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 18)
        }
        .background(Color.clear)
    }
}

private struct AboutLine: View {
    let icon: String, title: String, detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(SDTheme.green).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 13.5, weight: .semibold)); Text(detail).font(.system(size: 11.5)).foregroundStyle(SDTheme.muted).lineSpacing(2) }
        }
    }
}
