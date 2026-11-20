import SwiftUI

public struct DiscoverView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var library = LibraryService.shared
    
    @State private var collections = DiscoverCollections()
    @State private var similarArtists: [DiscoverArtist] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if isLoading && collections.albums.isEmpty && similarArtists.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(DowntifyColor.primary)
                            .scaleEffect(1.3)
                        Text("Discovering music based on your library...")
                            .font(DowntifyFont.body)
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else if let error = errorMessage, collections.albums.isEmpty && similarArtists.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundColor(.orange)
                        Text("Couldn't load recommendations")
                            .font(DowntifyFont.sectionTitle)
                            .foregroundColor(DowntifyColor.textPrimary)
                        Text(error)
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("Retry") {
                            Task { await loadDiscover() }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(DowntifyColor.primary)
                        .foregroundColor(.black)
                        .cornerRadius(20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    // MARK: - Recommended Playlists / Mixes
                    if !collections.playlists.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recommended For You")
                                .font(DowntifyFont.sectionTitle)
                                .foregroundColor(DowntifyColor.textPrimary)
                                .padding(.horizontal, 16)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(collections.playlists) { playlist in
                                        DiscoverPlaylistCard(playlist: playlist)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // MARK: - Suggested Albums
                    if !collections.albums.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggested Albums")
                                .font(DowntifyFont.sectionTitle)
                                .foregroundColor(DowntifyColor.textPrimary)
                                .padding(.horizontal, 16)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(collections.albums) { album in
                                        DiscoverAlbumCard(album: album)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // MARK: - Similar Artists
                    if !similarArtists.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Artists You Might Like")
                                .font(DowntifyFont.sectionTitle)
                                .foregroundColor(DowntifyColor.textPrimary)
                                .padding(.horizontal, 16)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(similarArtists) { artist in
                                        DiscoverArtistCard(artist: artist)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // MARK: - More Albums
                    if !collections.moreAlbums.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("More From Your Favorite Artists")
                                .font(DowntifyFont.sectionTitle)
                                .foregroundColor(DowntifyColor.textPrimary)
                                .padding(.horizontal, 16)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(collections.moreAlbums) { album in
                                        DiscoverAlbumCard(album: album)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                
                Spacer(minLength: 80)
            }
            .padding(.top, 12)
        }
        .background(theme.currentBackground.ignoresSafeArea())
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await loadDiscover()
        }
        .task {
            if collections.albums.isEmpty && similarArtists.isEmpty {
                await loadDiscover()
            }
        }
    }
    
    private func loadDiscover() async {
        isLoading = true
        errorMessage = nil
        do {
            let artistSeeds = Array(library.artists.prefix(5).map { $0.name })
            let result = try await DowntifyAPI.shared.fetchDiscover(artistSeeds: artistSeeds)
            self.similarArtists = result.artists
            self.collections = result.collections
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Component Cards

struct DiscoverPlaylistCard: View {
    let playlist: DiscoverPlaylist
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AuthenticatedArtworkImage(
                url: URL(string: playlist.coverUrl),
                size: 140,
                cornerRadius: DowntifyShape.coverRadius
            )
            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
            
            Text(playlist.name)
                .font(DowntifyFont.cardTitle)
                .foregroundColor(DowntifyColor.textPrimary)
                .lineLimit(1)
            
            Text(playlist.owner.isEmpty ? "Playlist" : playlist.owner)
                .font(DowntifyFont.caption)
                .foregroundColor(DowntifyColor.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 140)
    }
}

struct DiscoverAlbumCard: View {
    let album: DiscoverAlbum
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AuthenticatedArtworkImage(
                url: URL(string: album.coverUrl),
                size: 140,
                cornerRadius: DowntifyShape.coverRadius
            )
            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
            
            Text(album.name)
                .font(DowntifyFont.cardTitle)
                .foregroundColor(DowntifyColor.textPrimary)
                .lineLimit(1)
            
            Text(album.artist)
                .font(DowntifyFont.caption)
                .foregroundColor(DowntifyColor.textSecondary)
                .lineLimit(1)
            
            if let firstBecause = album.because.first, !firstBecause.isEmpty {
                Text("Because you like \(firstBecause)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(DowntifyColor.primary)
                    .lineLimit(1)
            }
        }
        .frame(width: 140)
    }
}

struct DiscoverArtistCard: View {
    let artist: DiscoverArtist
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            ZStack {
                if let url = URL(string: artist.pictureUrl), !artist.pictureUrl.isEmpty {
                    AuthenticatedArtworkImage(url: url, size: 100, cornerRadius: 50)
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.indigo.opacity(0.8), Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "music.mic")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.7))
                        )
                }
            }
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
            
            Text(artist.name)
                .font(DowntifyFont.cardTitle)
                .foregroundColor(DowntifyColor.textPrimary)
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
        .frame(width: 110)
    }
}
