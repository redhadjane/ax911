import SwiftUI

struct SystemHealthCard: View {
    let name: String
    let detail: String
    let state: CapabilityState
    var warning = false
    private var accent: Color { warning ? SDTheme.amber : state.color }
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text(detail).font(.system(size: 12, weight: .regular)).foregroundStyle(warning ? SDTheme.amber : SDTheme.muted).lineLimit(2)
            }
            Spacer(minLength: 0)
            Circle().fill(accent.opacity(0.12)).frame(width: 24, height: 24).overlay(Image(systemName: warning ? "exclamationmark" : state == .detected ? "checkmark" : "minus").font(.system(size: 11, weight: .bold)).foregroundStyle(accent))
        }
        .frame(minHeight: 68).premiumCard(padding: 13)
    }
}
