import SwiftUI

struct CarSettingsView: View {
    let demoMode: Bool
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 13) {
                HStack(alignment: .top) { ScreenHeader(title: "Car settings", subtitle: demoMode ? "Preview comfort controls without writing to the car." : "Capabilities unlock only after verified module discovery."); if demoMode { StatusBadge(text: "PREVIEW", color: SDTheme.cyan) } }
                safetyCard
                settingsGroup("Door & lock", items: [("Auto Lock", "Lock when driving", true), ("Auto Unlock", "Unlock when ignition turns off", true), ("Two-Press Unlock", "First press unlocks driver door", false), ("Confirmation Sound", "Audible lock confirmation", true)])
                settingsGroup("Exterior lighting", items: [("One-Touch Signal", "Three-flash lane change", true), ("Headlight Delay", "Keep lights on after exit", true), ("Welcome Light", "Approach illumination", true)])
                settingsGroup("Convenience", items: [("Smart Trunk", "Hands-free trunk opening", false), ("Smart Key Sound", "Key confirmation tone", true)])
                Text(demoMode ? "Preview switches are local and reset with the app. They do not change your vehicle." : "No setting is displayed as available until the module, command, readback, and rollback behavior are verified.")
                    .font(.system(size: 11)).foregroundStyle(SDTheme.muted).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

    private var safetyCard: some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack { Circle().fill(SDTheme.green.opacity(0.11)); Image(systemName: "lock.shield.fill").foregroundStyle(SDTheme.green) }.frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("Vehicle write lock is active").font(.system(size: 14.5, weight: .bold))
                Text("No experimental BCM, Smart Key, ABS, SRS, engine, or transmission command can be sent.").font(.system(size: 11.5)).foregroundStyle(SDTheme.muted).lineSpacing(2)
            }
        }.premiumCard(padding: 14, radius: 18)
    }

    private func settingsGroup(_ title: String, items: [(String, String, Bool)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    SettingRow(title: item.0, detail: item.1, initialValue: item.2, previewEnabled: demoMode)
                    if index < items.count - 1 { Divider().overlay(SDTheme.border) }
                }
            }.premiumCard(padding: 0, radius: 18)
        }
    }
}

private struct SettingRow: View {
    let title: String, detail: String
    let previewEnabled: Bool
    @State private var value: Bool

    init(title: String, detail: String, initialValue: Bool, previewEnabled: Bool) {
        self.title = title
        self.detail = detail
        self.previewEnabled = previewEnabled
        _value = State(initialValue: initialValue)
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 14, weight: .semibold)); Text(detail).font(.system(size: 11)).foregroundStyle(SDTheme.muted).lineLimit(1).minimumScaleFactor(0.8) }
            Spacer()
            if !previewEnabled { Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(SDTheme.tertiary) }
            Toggle("", isOn: $value).labelsHidden().disabled(!previewEnabled).scaleEffect(0.77).tint(SDTheme.green)
        }.padding(.horizontal, 15).padding(.vertical, 12)
    }
}

private struct MenuRow: View {
    let icon: String, title: String, detail: String
    let color: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(color).frame(width: 26)
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 17, weight: .semibold)); Text(detail).font(.system(size: 13)).foregroundStyle(SDTheme.muted) }
            Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(SDTheme.muted)
        }.premiumCard()
    }
}
