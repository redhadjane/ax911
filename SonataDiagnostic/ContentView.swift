import SwiftUI

struct ContentView: View {
    @State private var selection: AppTab = .home
    @State private var demoMode = false

    var body: some View {
        ZStack {
            SDTheme.background.ignoresSafeArea()

            switch selection {
            case .home: NavigationStack { LandingView(demoMode: $demoMode) }
            case .live: NavigationStack { LiveDataView(demoMode: demoMode) }
            case .diagnostics: NavigationStack { DiagnosticsView(demoMode: demoMode) }
            case .settings: NavigationStack { CarSettingsView(demoMode: demoMode) }
            case .vehicle: NavigationStack { VehicleView(demoMode: demoMode) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) { BottomNavigation(selection: $selection) }
        .background(SDTheme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
