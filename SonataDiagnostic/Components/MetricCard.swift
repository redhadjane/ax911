import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    var accent: Color = SDTheme.green
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(accent); Spacer(); Circle().fill(accent).frame(width: 6, height: 6) }
            Text(value).font(.system(size: 23, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.85)
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(SDTheme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading).premiumCard(padding: 15)
    }
}
