import SwiftUI

@main
struct FICSIT_TerminalApp: App {
    // Shared dependency created at app root
    @StateObject private var worldService = WorldService.shared

    var body: some Scene {
        WindowGroup {
            ContentView(worldService: worldService)
        }
    }
}
