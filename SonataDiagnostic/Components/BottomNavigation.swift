import SwiftUI

struct BottomNavigation: View {
    @Binding var selection: AppRoute
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppRoute.bottomRoutes) { tab in
                Button { withAnimation(.easeOut(duration: 0.16)) { selection = tab } } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selection == tab ? selectedIcon(for: tab) : tab.icon).font(.system(size: 18, weight: .semibold)).frame(height: 21)
                        Text(tab.rawValue).font(.system(size: 9.5, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.86)
                    }
                    .foregroundStyle(selection == tab ? SDTheme.green : SDTheme.muted)
                    .frame(maxWidth: .infinity).frame(height: 60).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel(tab.rawValue).accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .background(SDTheme.background.opacity(0.97))
        .overlay(alignment: .top) { Rectangle().fill(SDTheme.border).frame(height: 0.7) }
    }

    private func selectedIcon(for route: AppRoute) -> String {
        switch route {
        case .overview: return "house.fill"
        case .live: return "chart.bar.fill"
        case .diagnostics: return "car.rear.waves.up"
        case .settings: return "slider.horizontal.3"
        default: return route.icon
        }
    }
}
