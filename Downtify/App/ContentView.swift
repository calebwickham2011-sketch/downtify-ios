import SwiftUI

public enum TabDestination: Hashable {
    case home
    case search
    case library
}

public struct ContentView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var selectedTab: TabDestination = .home
    @State private var showSettings = false
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
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
            
            // Docked MiniPlayer Preview (Phase 6 full morph target)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: DowntifyShape.coverRadius, style: .continuous)
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.white.opacity(0.8))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Midnight City")
                            .font(DowntifyFont.cardTitle)
                            .foregroundColor(DowntifyColor.textPrimary)
                            .lineLimit(1)
                        
                        Text("M83 • Hurry Up, We're Dreaming")
                            .font(DowntifyFont.cardSubtitle)
                            .foregroundColor(DowntifyColor.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: DowntifyIcons.play)
                            .font(.system(size: 20))
                            .foregroundColor(DowntifyColor.textPrimary)
                    }
                    .padding(.trailing, 8)
                    
                    Button(action: {}) {
                        Image(systemName: DowntifyIcons.forward)
                            .font(.system(size: 20))
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: DowntifyShape.miniPlayerRadius, style: .continuous)
                        .fill(DowntifyColor.surfaceRaised)
                        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 54) // Positions right above the iOS TabBar
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
    }
}
