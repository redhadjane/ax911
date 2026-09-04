import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var obd: OBDLinkCXManager
    @State private var route: AppRoute = .overview
    @State private var demoMode = false
    @State private var demoScenario: DemoScenario = .intake
    @State private var menuPresented = false
    @State private var demoScanPresented = false

    private var realSessionActive: Bool {
        obd.state == .connected || obd.state == .reading || obd.state == .finished
    }

    private var scanInProgress: Bool {
        obd.state == .scanning || obd.state == .connecting || obd.state == .reading
    }

    var body: some View {
        ZStack {
            SDTheme.background.ignoresSafeArea()

            if demoMode || realSessionActive {
                connectedShell
            } else {
                LandingView(onStartDemo: startDemo)
            }

            if menuPresented {
                SideMenu(
                    route: $route,
                    scenario: $demoScenario,
                    demoMode: demoMode,
                    onClose: { withAnimation(.easeOut(duration: 0.2)) { menuPresented = false } },
                    onDisconnect: disconnect
                )
                .transition(.opacity)
                .zIndex(4)
            }

            if scanInProgress || demoScanPresented {
                ScanProgressOverlay(
                    progress: demoScanPresented ? 100 : max(obd.progress, 5),
                    message: demoScanPresented ? "Building capability profile…" : obd.message
                )
                .transition(.opacity)
                .zIndex(5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SDTheme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.22), value: menuPresented)
    }

    private var connectedShell: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppTopBar(
                    title: route.rawValue,
                    demoMode: demoMode,
                    onMenu: { withAnimation { menuPresented = true } },
                    onVehicle: { route = .vehicle }
                )
                routeScreen
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomNavigation(selection: $route)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder private var routeScreen: some View {
        switch route {
        case .overview:
            OverviewView(demoMode: demoMode, scenario: demoScenario, onOpenDiagnostics: { route = .diagnostics })
        case .live:
            LiveDataView(demoMode: demoMode, scenario: demoScenario)
        case .diagnostics:
            DiagnosticsView(demoMode: demoMode, scenario: demoScenario)
        case .vehicle:
            VehicleView(demoMode: demoMode, scenario: demoScenario)
        case .settings:
            CarSettingsView(demoMode: demoMode)
        case .reports:
            ReportsView()
        case .maintenance:
            MaintenanceView(demoMode: demoMode)
        case .logging:
            DataLoggingView(demoMode: demoMode)
        case .profile:
            VehicleProfileView(demoMode: demoMode, scenario: demoScenario)
        case .about:
            AboutView()
        }
    }

    private func startDemo() {
        obd.disconnect()
        demoScanPresented = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            route = .overview
            demoMode = true
            withAnimation { demoScanPresented = false }
        }
    }

    private func disconnect() {
        menuPresented = false
        demoMode = false
        route = .overview
        obd.disconnect()
    }
}
