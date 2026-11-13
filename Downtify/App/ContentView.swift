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

            // Live Mini Player — hidden when nothing is playing
            if player.currentTrack != nil {
                MiniPlayerBar()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 54)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
    }
}

// MARK: - Mini Player Bar

struct MiniPlayerBar: View {
    @ObservedObject private var player = AudioPlayerManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            if let track = player.currentTrack, track.hasCover,
               let url = DowntifyAPI.shared.coverUrl(trackId: track.id, size: 100) {
                AuthenticatedArtworkImage(url: url, size: 44, cornerRadius: 6)
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "music.note").foregroundColor(.white.opacity(0.8)))
            }

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(player.currentTrack?.displayTitle ?? "")
                    .font(DowntifyFont.cardTitle)
                    .foregroundColor(DowntifyColor.textPrimary)
                    .lineLimit(1)
                Text(player.currentTrack?.displayArtist ?? "")
                    .font(DowntifyFont.cardSubtitle)
                    .foregroundColor(DowntifyColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Play / Pause
            Button {
                player.togglePlayPause()
            } label: {
                Group {
                    if player.state == .loading {
                        ProgressView().tint(DowntifyColor.textPrimary)
                    } else {
                        Image(systemName: player.state == .playing ? DowntifyIcons.pause : DowntifyIcons.play)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(DowntifyColor.textPrimary)
                    }
                }
                .frame(width: 32, height: 32)
            }

            // Skip next
            Button {
                player.skipToNext()
            } label: {
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
        // Thin seek progress line across the bottom of the bar
        .overlay(alignment: .bottom) {
            if player.duration > 0 {
                GeometryReader { geo in
                    Rectangle()
                        .fill(DowntifyColor.primary)
                        .frame(width: geo.size.width * CGFloat(player.currentTime / player.duration), height: 2)
                }
                .frame(height: 2)
                .clipShape(RoundedRectangle(cornerRadius: DowntifyShape.miniPlayerRadius))
            }
        }
    }
}

