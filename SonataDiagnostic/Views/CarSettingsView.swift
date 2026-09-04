import SwiftUI

struct CarSettingsView: View {
    @EnvironmentObject private var reports: ReportStore
    let demoMode: Bool
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack { ScreenHeader(title: "Car Settings", subtitle: "Verified capabilities only. Experimental writes stay locked."); if demoMode { StatusBadge(text: "DEMO", color: SDTheme.amber) } }
                safetyCard
                settingsGroup("Door / Lock", items: [("Auto Lock", "Enable when driving"), ("Auto Unlock", "On ignition off"), ("Two Press Unlock", "Unlock all doors"), ("Door Lock Sound", "Confirmation chirp")])
                settingsGroup("Lights", items: [("One-Touch Signal", "Flash count"), ("Headlight Delay", "Delay after exit"), ("Welcome Light", "Approach lighting")])
                settingsGroup("Convenience", items: [("Smart Trunk", "Hands-free opening"), ("Smart Key Beep", "Key confirmation")])
                NavigationLink { ReportsView() } label: { MenuRow(icon: "doc.text.fill", title: "Reports", detail: "\(reports.reports.count) saved", color: SDTheme.green) }.buttonStyle(.plain)
                NavigationLink { AboutView() } label: { MenuRow(icon: "info.circle.fill", title: "About", detail: "Privacy and safety", color: SDTheme.muted) }.buttonStyle(.plain)
            }.padding(16)
        }
        .background(SDTheme.background).navigationBarHidden(true)
    }

    private var safetyCard: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "lock.shield.fill").foregroundStyle(SDTheme.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("Write safety lock is on").font(.headline)
                Text("Every listed Hyundai setting is tracked as unverified research. No BCM, Smart Key, ABS, SRS, immobilizer, steering, engine, or transmission write is sent.").font(.caption).foregroundStyle(SDTheme.muted)
            }
        }.premiumCard()
    }

    private func settingsGroup(_ title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    SettingRow(title: item.0, detail: item.1)
                    if index < items.count - 1 { Divider().overlay(SDTheme.border) }
                }
            }.premiumCard(padding: 0)
        }
    }
}

private struct SettingRow: View {
    let title: String, detail: String
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) { Text(title).font(.subheadline.weight(.medium)); Text(detail).font(.caption).foregroundStyle(SDTheme.muted) }
            Spacer()
            StatusBadge(text: "RESEARCH", color: SDTheme.amber)
            Toggle("", isOn: .constant(false)).labelsHidden().disabled(true).scaleEffect(0.78)
        }.padding(.horizontal, 14).padding(.vertical, 11)
    }
}

private struct MenuRow: View {
    let icon: String, title: String, detail: String
    let color: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) { Text(title).font(.subheadline.weight(.semibold)); Text(detail).font(.caption).foregroundStyle(SDTheme.muted) }
            Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(SDTheme.muted)
        }.premiumCard()
    }
}
