import SwiftUI

@main
struct SonataDiagnosticApp: App {
    @StateObject private var obd = OBDLinkCXManager()
    @StateObject private var reports = ReportStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(obd)
                .environmentObject(reports)
                .preferredColorScheme(.dark)
        }
    }
}
