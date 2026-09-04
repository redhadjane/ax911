import SwiftUI

struct BottomNavigation: View {
    @Binding var selection: AppRoute
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppRoute.bottomRoutes) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon).font(.system(size: 20, weight: .semibold))
                        Text(tab.rawValue).font(.system(size: 10.5, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.82)
                        Circle().fill(selection == tab ? SDTheme.green : .clear).frame(width: 4, height: 4)
                    }
                    .foregroundStyle(selection == tab ? Color.white : SDTheme.muted)
                    .frame(maxWidth: .infinity).frame(height: 66).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel(tab.rawValue).accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8).padding(.top, 5).background(SDTheme.background.opacity(0.98)).overlay(alignment: .top) { Rectangle().fill(SDTheme.border).frame(height: 0.7) }
    }
}
