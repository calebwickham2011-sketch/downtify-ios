import SwiftUI

public struct HomeView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var library = LibraryRepository.shared
    @ObservedObject var sessionStore = KeychainSessionStore.shared
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Header Greeting
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greetingText)
                                .font(DowntifyFont.hero)
                                .foregroundColor(DowntifyColor.textPrimary)
                            
                            if let session = sessionStore.session {
                                Text("Connected to \(session.serverName.isEmpty ? "Downtify" : session.serverName)")
                                    .font(DowntifyFont.body)
                                    .foregroundColor(DowntifyColor.textSecondary)
                            }
                        }
                        Spacer()
                        
                        if library.isSyncing {
                            ProgressView()
                                .tint(DowntifyColor.primary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // Quick Picks Grid
                    if !quickPicks.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(quickPicks, id: \.id) { pick in
                                HStack(spacing: 10) {
                                    if let coverUrl = pick.coverUrl {
                                        AuthenticatedArtworkImage(
                                            url: coverUrl,
                                            size: 52,
                                            cornerRadius: 6
                                        )
                                    } else {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 52, height: 52)
                                            .overlay(
                                                Image(systemName: "music.note")
                                                    .foregroundColor(.white.opacity(0.8))
                                            )
                                    }
                                    
                                    Text(pick.title)
                                        .font(DowntifyFont.cardTitle)
                                        .foregroundColor(DowntifyColor.textPrimary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer(minLength: 0)
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(DowntifyColor.surfaceRaised)
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Recently Added Albums Carousel
                    if !library.albums.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Recently Added")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(library.albums.prefix(10)) { album in
                                        VStack(alignment: .leading, spacing: 8) {
                                            let coverUrl = album.coverTrackId.flatMap { DowntifyAPI.shared.coverUrl(trackId: $0, size: 300) }
                                            AuthenticatedArtworkImage(
                                                url: coverUrl,
                                                size: 140,
                                                cornerRadius: DowntifyShape.coverRadius
                                            )
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(album.title)
                                                    .font(DowntifyFont.cardTitle)
                                                    .foregroundColor(DowntifyColor.textPrimary)
                                                    .lineLimit(1)
                                                
                                                Text(album.artist)
                                                    .font(DowntifyFont.cardSubtitle)
                                                    .foregroundColor(DowntifyColor.textSecondary)
                                                    .lineLimit(1)
                                            }
                                            .frame(width: 140, alignment: .leading)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // Featured Artists Carousel
                    if !library.artists.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Artists in Your Library")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(library.artists.prefix(10)) { artist in
                                        VStack(spacing: 8) {
                                            let coverUrl = artist.coverTrackId.flatMap { DowntifyAPI.shared.coverUrl(trackId: $0, size: 300) }
                                            AuthenticatedArtworkImage(
                                                url: coverUrl,
                                                size: 110,
                                                cornerRadius: 55
                                            )
                                            
                                            Text(artist.name)
                                                .font(DowntifyFont.cardSubtitle)
                                                .foregroundColor(DowntifyColor.textPrimary)
                                                .lineLimit(1)
                                                .frame(width: 110)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // Empty state if server has no music yet
                    if library.tracks.isEmpty && !library.isSyncing {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 48))
                                .foregroundColor(DowntifyColor.textSecondary)
                            Text("No tracks found")
                                .font(DowntifyFont.sectionTitle)
                                .foregroundColor(DowntifyColor.textPrimary)
                            Text("Pull down to sync with your Downtify server.")
                                .font(DowntifyFont.caption)
                                .foregroundColor(DowntifyColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                    
                    Spacer(minLength: 80)
                }
            }
            .background(theme.currentBackground.ignoresSafeArea())
            .refreshable {
                await library.syncWithServer(forceFull: true)
            }
            .onAppear {
                LiveUpdatesClient.shared.start()
                if library.tracks.isEmpty {
                    Task {
                        await library.syncWithServer()
                    }
                }
            }
        }
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }
    
    private struct QuickPickItem: Identifiable {
        let id: String
        let title: String
        let coverUrl: URL?
    }
    
    private var quickPicks: [QuickPickItem] {
        var items: [QuickPickItem] = []
        if !library.likedTrackIds.isEmpty {
            items.append(QuickPickItem(id: "liked_songs", title: "Liked Songs", coverUrl: nil))
        }
        for p in library.playlists.prefix(3) {
            let coverUrl = DowntifyAPI.shared.playlistCoverUrl(path: p.cover)
            items.append(QuickPickItem(id: "playlist_\(p.name)", title: p.title, coverUrl: coverUrl))
        }
        for a in library.albums.prefix(6 - items.count) {
            let coverUrl = a.coverTrackId.flatMap { DowntifyAPI.shared.coverUrl(trackId: $0, size: 150) }
            items.append(QuickPickItem(id: "album_\(a.id)", title: a.title, coverUrl: coverUrl))
        }
        return items
    }
}
