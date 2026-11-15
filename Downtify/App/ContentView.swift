import SwiftUI

public enum TabDestination: Hashable {
    case home
    case search
    case library
}

public struct ContentView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject private var player = AudioPlayerManager.shared
    @State private var selectedTab: TabDestination = .home
    @State private var showSettings = false
    @State private var isNowPlayingExpanded = false

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Main Tab View
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: selectedTab == .home ? DowntifyIcons.home : DowntifyIcons.homeOutline)
                    }
                    .tag(TabDestination.home)

                SearchView()
                    .tabItem {
                        Label("Search", systemImage: DowntifyIcons.search)
                    }
                    .tag(TabDestination.search)

                LibraryView()
                    .tabItem {
                        Label("Your Library", systemImage: selectedTab == .library ? DowntifyIcons.library : DowntifyIcons.libraryOutline)
                    }
                    .tag(TabDestination.library)
            }
            .tint(DowntifyColor.primary)

            // Docked MiniPlayer — visible right above the TabBar when a track is active
            if player.currentTrack != nil && !isNowPlayingExpanded {
                MiniPlayerView(onExpand: {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                        isNowPlayingExpanded = true
                    }
                })
                .padding(.horizontal, 10)
                .padding(.bottom, 54)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
            
            // Full-screen Expandable NowPlayingView
            if isNowPlayingExpanded && player.currentTrack != nil {
                NowPlayingView(onDismiss: {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                        isNowPlayingExpanded = false
                    }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .zIndex(100)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showSettings = true }) {
                    Image(systemName: DowntifyIcons.settings)
                        .foregroundColor(DowntifyColor.textPrimary)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.35), value: player.currentTrack?.id)
        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: isNowPlayingExpanded)
    }
}
