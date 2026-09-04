import SwiftUI

struct BottomNavigation: View {
    @Binding var selection: AppTab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon).font(.system(size: 17, weight: .semibold))
                        Text(tab.rawValue).font(.system(size: 9.5, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selection == tab ? SDTheme.green : SDTheme.muted)
                    .frame(maxWidth: .infinity).frame(height: 54).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel(tab.rawValue).accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6).padding(.top, 4).background(.ultraThinMaterial).background(Color.black.opacity(0.82)).overlay(alignment: .top) { Rectangle().fill(SDTheme.border).frame(height: 0.7) }
    }
}
