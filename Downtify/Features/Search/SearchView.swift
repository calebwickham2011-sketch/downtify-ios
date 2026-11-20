import SwiftUI

public struct SearchView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var library = LibraryService.shared
    @ObservedObject var player = AudioPlayerManager.shared
    
    @State private var query = ""
    @State private var selectedFilter = "All"
    @State private var catalogResults = CatalogSearchResult()
    @State private var isSearchingCatalog = false
    @State private var searchTask: Task<Void, Never>?
    
    let filters = ["All", "Tracks", "Albums", "Artists", "Playlists"]
    
    let browseCategories: [(String, Color, AnyView)] = [
        ("Discover", .indigo, AnyView(DiscoverView())),
        ("Podcasts", .orange, AnyView(PodcastsView())),
        ("Playlists", .purple, AnyView(LibraryView())),
        ("New Releases", .pink, AnyView(DiscoverView())),
        ("Rock", .red, AnyView(DiscoverView())),
        ("Hip-Hop", .yellow, AnyView(DiscoverView())),
        ("Indie", .blue, AnyView(DiscoverView())),
        ("Electronic", .mint, AnyView(DiscoverView())),
        ("Jazz", .brown, AnyView(DiscoverView())),
        ("Classical", .teal, AnyView(DiscoverView()))
    ]
    
    public init() {}
    
    // MARK: - Local Filtered Results
    
    private var matchingTracks: [Track] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return library.tracks.filter {
            TextSearch.matches(query: query, fields: [$0.title, $0.artist, $0.album, $0.albumArtist])
        }
    }
    
    private var matchingAlbums: [Album] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return library.albums.filter {
            TextSearch.matches(query: query, fields: [$0.title, $0.artist])
        }
    }
    
    private var matchingArtists: [Artist] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return library.artists.filter {
            TextSearch.matches(query: query, fields: [$0.name])
        }
    }
    
    private var matchingPlaylists: [Playlist] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return library.playlists.filter {
            TextSearch.matches(query: query, fields: [$0.name])
        }
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Input Header
                HStack(spacing: 10) {
                    Image(systemName: DowntifyIcons.search)
                        .foregroundColor(DowntifyColor.textSecondary)
                    
                    TextField("What do you want to play?", text: $query)
                        .font(DowntifyFont.body)
                        .foregroundColor(DowntifyColor.textPrimary)
                        .autocorrectionDisabled()
                        .onChange(of: query) { _, newQuery in
                            performDebouncedRemoteSearch(for: newQuery)
                        }
                    
                    if !query.isEmpty {
                        Button(action: {
                            query = ""
                            catalogResults = CatalogSearchResult()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DowntifyColor.textSecondary)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: DowntifyShape.cardRadius, style: .continuous)
                        .fill(DowntifyColor.surfaceRaised)
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // MARK: - Browse Categories
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Browse All")
                                .font(DowntifyFont.sectionTitle)
                                .foregroundColor(DowntifyColor.textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                            
                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                                spacing: 12
                            ) {
                                ForEach(browseCategories, id: \.0) { cat in
                                    NavigationLink(destination: cat.2) {
                                        ZStack(alignment: .topLeading) {
                                            RoundedRectangle(cornerRadius: DowntifyShape.coverRadius, style: .continuous)
                                                .fill(cat.1.gradient)
                                                .frame(height: 96)
                                            
                                            Text(cat.0)
                                                .font(DowntifyFont.sectionTitle)
                                                .foregroundColor(.white)
                                                .padding(12)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            Spacer(minLength: 80)
                        }
                    }
                } else {
                    // MARK: - Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters, id: \.self) { filter in
                                PillFilter(
                                    title: filter,
                                    isSelected: selectedFilter == filter,
                                    action: { selectedFilter = filter }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                    
                    // MARK: - Active Search Results List
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            // Library Tracks
                            if (selectedFilter == "All" || selectedFilter == "Tracks") && !matchingTracks.isEmpty {
                                SearchSectionHeader(title: "Songs (\(matchingTracks.count))")
                                ForEach(matchingTracks.prefix(selectedFilter == "All" ? 5 : 50)) { track in
                                    SearchTrackRow(track: track, isCurrentlyPlaying: player.currentTrack?.id == track.id) {
                                        player.play(track: track, context: "Search: \(query)")
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            
                            // Library Albums
                            if (selectedFilter == "All" || selectedFilter == "Albums") && !matchingAlbums.isEmpty {
                                SearchSectionHeader(title: "Albums (\(matchingAlbums.count))")
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(matchingAlbums) { album in
                                            NavigationLink(destination: AlbumDetailView(album: album)) {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    let coverUrl = album.coverTrackId.flatMap { DowntifyAPI.shared.coverUrl(trackId: $0, size: 240) }
                                                    AuthenticatedArtworkImage(url: coverUrl, size: 120, cornerRadius: DowntifyShape.coverRadius)
                                                    Text(album.title)
                                                        .font(DowntifyFont.cardTitle)
                                                        .foregroundColor(DowntifyColor.textPrimary)
                                                        .lineLimit(1)
                                                    Text(album.artist)
                                                        .font(DowntifyFont.caption)
                                                        .foregroundColor(DowntifyColor.textSecondary)
                                                        .lineLimit(1)
                                                }
                                                .frame(width: 120)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            
                            // Library Artists
                            if (selectedFilter == "All" || selectedFilter == "Artists") && !matchingArtists.isEmpty {
                                SearchSectionHeader(title: "Artists (\(matchingArtists.count))")
                                ForEach(matchingArtists) { artist in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(DowntifyColor.surfaceRaised)
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "music.mic").foregroundColor(DowntifyColor.primary))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(artist.name)
                                                .font(DowntifyFont.bodyBold)
                                                .foregroundColor(DowntifyColor.textPrimary)
                                            Text("Artist • \(artist.tracks.count) tracks")
                                                .font(DowntifyFont.caption)
                                                .foregroundColor(DowntifyColor.textSecondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            
                            // Library Playlists
                            if (selectedFilter == "All" || selectedFilter == "Playlists") && !matchingPlaylists.isEmpty {
                                SearchSectionHeader(title: "Playlists (\(matchingPlaylists.count))")
                                ForEach(matchingPlaylists) { playlist in
                                    NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                        HStack(spacing: 14) {
                                            let coverUrl = DowntifyAPI.shared.playlistCoverUrl(path: playlist.cover)
                                            AuthenticatedArtworkImage(url: coverUrl, size: 48, cornerRadius: 8)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(playlist.name)
                                                    .font(DowntifyFont.bodyBold)
                                                    .foregroundColor(DowntifyColor.textPrimary)
                                                Text("Playlist")
                                                    .font(DowntifyFont.caption)
                                                    .foregroundColor(DowntifyColor.textSecondary)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            // Remote Catalog Search Results
                            if isSearchingCatalog {
                                HStack(spacing: 8) {
                                    ProgressView().tint(DowntifyColor.primary)
                                    Text("Searching server catalog...")
                                        .font(DowntifyFont.caption)
                                        .foregroundColor(DowntifyColor.textSecondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                            } else if !catalogResults.songs.isEmpty || !catalogResults.albums.isEmpty {
                                if !catalogResults.songs.isEmpty && (selectedFilter == "All" || selectedFilter == "Tracks") {
                                    SearchSectionHeader(title: "Server Catalog Songs")
                                    ForEach(catalogResults.songs) { remoteSong in
                                        RemoteSongRow(song: remoteSong) {
                                            let playable = Track(remote: remoteSong)
                                            player.play(track: playable, context: "Catalog: \(query)")
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                                
                                if !catalogResults.albums.isEmpty && (selectedFilter == "All" || selectedFilter == "Albums") {
                                    SearchSectionHeader(title: "Server Catalog Albums")
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(catalogResults.albums) { remoteAlbum in
                                                VStack(alignment: .leading, spacing: 6) {
                                                    AuthenticatedArtworkImage(
                                                        url: URL(string: remoteAlbum.coverUrl),
                                                        size: 120,
                                                        cornerRadius: DowntifyShape.coverRadius
                                                    )
                                                    Text(remoteAlbum.title)
                                                        .font(DowntifyFont.cardTitle)
                                                        .foregroundColor(DowntifyColor.textPrimary)
                                                        .lineLimit(1)
                                                    Text(remoteAlbum.artist)
                                                        .font(DowntifyFont.caption)
                                                        .foregroundColor(DowntifyColor.textSecondary)
                                                        .lineLimit(1)
                                                }
                                                .frame(width: 120)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                            
                            Spacer(minLength: 80)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .background(theme.currentBackground.ignoresSafeArea())
            .navigationTitle("Search")
        }
    }
    
    private func performDebouncedRemoteSearch(for text: String) {
        searchTask?.cancel()
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else {
            catalogResults = CatalogSearchResult()
            isSearchingCatalog = false
            return
        }
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            
            await MainActor.run { isSearchingCatalog = true }
            do {
                let results = try await DowntifyAPI.shared.searchCatalog(query: clean)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.catalogResults = results
                    self.isSearchingCatalog = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.isSearchingCatalog = false
                }
            }
        }
    }
}

// MARK: - Row Components

struct SearchSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(DowntifyFont.cardTitle)
            .foregroundColor(DowntifyColor.textSecondary)
            .padding(.horizontal, 16)
            .padding(.top, 6)
    }
}

struct SearchTrackRow: View {
    let track: Track
    let isCurrentlyPlaying: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                let coverUrl = DowntifyAPI.shared.coverUrl(trackId: track.id, size: 100)
                AuthenticatedArtworkImage(url: coverUrl, size: 44, cornerRadius: 6)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.displayTitle)
                        .font(DowntifyFont.body)
                        .foregroundColor(isCurrentlyPlaying ? DowntifyColor.primary : DowntifyColor.textPrimary)
                        .lineLimit(1)
                    
                    Text(track.displayArtist)
                        .font(DowntifyFont.caption)
                        .foregroundColor(DowntifyColor.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isCurrentlyPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(DowntifyColor.primary)
                        .font(.system(size: 14))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct RemoteSongRow: View {
    let song: RemoteSong
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AuthenticatedArtworkImage(
                    url: URL(string: song.coverUrl),
                    size: 44,
                    cornerRadius: 6
                )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(DowntifyFont.body)
                        .foregroundColor(DowntifyColor.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "cloud")
                            .font(.system(size: 10))
                            .foregroundColor(DowntifyColor.primary)
                        Text(song.artist)
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "play.circle.fill")
                    .foregroundColor(DowntifyColor.primary)
                    .font(.system(size: 24))
            }
        }
        .buttonStyle(.plain)
    }
}
