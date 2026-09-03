import SwiftUI

@main
struct SonataDiagnosticApp: App {
    @StateObject private var obd = OBDLinkCXManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(obd)
                .preferredColorScheme(.dark)
        }
    }
}
