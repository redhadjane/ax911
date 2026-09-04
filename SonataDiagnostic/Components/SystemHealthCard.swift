import SwiftUI

struct SystemHealthCard: View {
    let name: String
    let detail: String
    let state: CapabilityState
    var warning = false
    private var accent: Color { warning ? SDTheme.amber : state.color }
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(accent.opacity(0.12)).frame(width: 28, height: 28).overlay(Image(systemName: warning ? "exclamationmark" : "checkmark").font(.caption.bold()).foregroundStyle(accent))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(detail).font(.caption2).foregroundStyle(warning ? SDTheme.amber : SDTheme.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .premiumCard(padding: 11)
    }
}
