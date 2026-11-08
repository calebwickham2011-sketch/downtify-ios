import SwiftUI
import SwiftData

@main
struct DowntifyApp: App {
    @StateObject private var theme = ThemeManager.shared
    @StateObject private var sessionStore = KeychainSessionStore.shared
    @StateObject private var library = LibraryRepository.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if sessionStore.session != nil {
                    ContentView()
                } else {
                    ConnectView()
                }
            }
            .modelContainer(library.modelContainer)
            .preferredColorScheme(.dark)
        }
    }
}
