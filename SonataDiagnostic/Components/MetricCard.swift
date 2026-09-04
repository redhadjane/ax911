import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    var accent: Color = SDTheme.green
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: icon).foregroundStyle(accent); Spacer(); Circle().fill(accent).frame(width: 5, height: 5) }
            Text(value).font(.title3.weight(.semibold).monospacedDigit()).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(SDTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading).premiumCard(padding: 12)
    }
}
