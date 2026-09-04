import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var obd: OBDLinkCXManager
    @State private var route: AppRoute
    @State private var demoMode: Bool
    @State private var demoScenario: DemoScenario
    @State private var menuPresented: Bool
    @State private var demoScanPresented = false

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let testingDemo = arguments.contains("-ui-testing-demo")
        let testingMenu = arguments.contains("-ui-testing-menu")
        let routeName = Self.argument(after: "-ui-testing-route", in: arguments)
        _route = State(initialValue: Self.route(named: routeName) ?? .overview)
        _demoMode = State(initialValue: testingDemo)
        _demoScenario = State(initialValue: .intake)
        _menuPresented = State(initialValue: testingMenu)
    }

    private var realSessionActive: Bool {
        obd.state == .connected || obd.state == .reading || obd.state == .finished
    }

    private var scanInProgress: Bool {
        obd.state == .scanning || obd.state == .connecting || obd.state == .reading
    }

    var body: some View {
        ZStack {
            AppBackdrop().ignoresSafeArea()
            GeometryReader { proxy in
                ZStack {
                    if demoMode || realSessionActive {
                        connectedShell
                            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    } else {
                        LandingView(onStartDemo: startDemo)
                            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    }

                    if menuPresented {
                        SideMenu(
                            route: $route,
                            scenario: $demoScenario,
                            demoMode: demoMode,
                            onClose: { withAnimation(.easeOut(duration: 0.2)) { menuPresented = false } },
                            onDisconnect: disconnect
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .transition(.opacity)
                        .zIndex(4)
                    }

                    if scanInProgress || demoScanPresented {
                        ScanProgressOverlay(
                            progress: demoScanPresented ? 100 : max(obd.progress, 5),
                            message: demoScanPresented ? "Building capability profile…" : obd.message
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .transition(.opacity)
                        .zIndex(5)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.22), value: menuPresented)
    }

    private var connectedShell: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: route.rawValue,
                demoMode: demoMode,
                onMenu: { withAnimation(.spring(response: 0.30, dampingFraction: 0.9)) { menuPresented = true } },
                onVehicle: { withAnimation(.easeInOut(duration: 0.18)) { route = .vehicle } }
            )
            routeScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            BottomNavigation(selection: $route)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private var routeScreen: some View {
        switch route {
        case .overview:
            OverviewView(demoMode: demoMode, scenario: demoScenario, onOpenDiagnostics: { route = .diagnostics })
        case .intelligence:
            IntelligenceView(demoMode: demoMode, scenario: demoScenario)
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

    private static func argument(after key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func route(named name: String?) -> AppRoute? {
        switch name?.lowercased() {
        case "overview": return .overview
        case "intelligence": return .intelligence
        case "live": return .live
        case "diagnostics": return .diagnostics
        case "vehicle": return .vehicle
        case "settings": return .settings
        case "reports": return .reports
        case "maintenance": return .maintenance
        case "logging": return .logging
        case "profile": return .profile
        case "about": return .about
        default: return nil
        }
    }
}
