import SwiftUI

struct BottomNavigation: View {
    @Binding var selection: AppTab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon).font(.system(size: 21, weight: .semibold))
                        Text(tab.rawValue).font(.system(size: 11, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.9)
                    }
                    .foregroundStyle(selection == tab ? SDTheme.green : SDTheme.muted)
                    .frame(maxWidth: .infinity).frame(height: 66).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel(tab.rawValue).accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8).padding(.top, 5).background(.ultraThinMaterial).background(Color.black.opacity(0.88)).overlay(alignment: .top) { Rectangle().fill(SDTheme.border).frame(height: 0.7) }
    }
}
