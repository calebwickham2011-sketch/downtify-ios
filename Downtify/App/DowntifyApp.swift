import SwiftUI

@main
struct DowntifyApp: App {
    @StateObject private var theme = ThemeManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
