import SwiftUI

@main struct HOPCommandApp: App {
    var body: some Scene {
        WindowGroup { CommandWorkspace().ignoresSafeArea(.keyboard) }
    }
}
private struct CommandWorkspace: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CommandViewController { CommandViewController() }
    func updateUIViewController(_ controller: CommandViewController, context: Context) {}
}
