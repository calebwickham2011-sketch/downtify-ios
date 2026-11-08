import SwiftUI

@main
struct DowntifyApp: App {
    @StateObject private var theme = ThemeManager.shared
    @StateObject private var sessionStore = KeychainSessionStore.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if sessionStore.session != nil {
                    ContentView()
                } else {
                    ConnectView()
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
