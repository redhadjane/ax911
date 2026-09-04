import SwiftUI

struct SystemHealthCard: View {
    let name: String
    let detail: String
    let state: CapabilityState
    var warning = false
    private var accent: Color { warning ? SDTheme.amber : state.color }
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.78).layoutPriority(1)
                Text(detail).font(.system(size: 11.5, weight: .regular)).foregroundStyle(warning ? SDTheme.amber : SDTheme.muted).lineLimit(1).minimumScaleFactor(0.82)
            }
            Spacer(minLength: 0)
            Circle().fill(accent.opacity(0.12)).frame(width: 23, height: 23).overlay(Image(systemName: warning ? "exclamationmark" : state == .detected ? "checkmark" : "minus").font(.system(size: 10, weight: .bold)).foregroundStyle(accent))
        }
        .frame(maxWidth: .infinity, minHeight: 47, alignment: .top).premiumCard(padding: 13, radius: 17)
    }
}
