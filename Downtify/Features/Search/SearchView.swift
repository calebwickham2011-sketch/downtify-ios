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
    @State private var showSettings = false
    @State private var actionNotification: String? = nil
    @State private var downloadingIds: Set<String> = []
    
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
    
    /// Returns tracks whose title or artist matches the search terms.
    /// Does NOT match tracks simply because their album matches the query!
    /// Sorted by title match relevance (exact match first, prefix, then alphabetical), NOT by album!
    private var matchingTracks: [Track] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let cleanQuery = TextSearch.normalize(query)
        let filtered = library.tracks.filter {
            TextSearch.matches(query: query, fields: [$0.displayTitle, $0.title, $0.artist] + $0.artists)
        }
        return filtered.sorted { t1, t2 in
            let title1 = TextSearch.normalize(t1.displayTitle)
            let title2 = TextSearch.normalize(t2.displayTitle)
            let exact1 = title1 == cleanQuery
            let exact2 = title2 == cleanQuery
            if exact1 != exact2 { return exact1 }
            let prefix1 = title1.hasPrefix(cleanQuery)
            let prefix2 = title2.hasPrefix(cleanQuery)
            if prefix1 != prefix2 { return prefix1 }
            return title1.localizedCaseInsensitiveCompare(title2) == .orderedAscending
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
                                ForEach(matchingTracks.prefix(selectedFilter == "All" ? 5 : 100)) { track in
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
                                // Server Catalog Songs
                                if !catalogResults.songs.isEmpty && (selectedFilter == "All" || selectedFilter == "Tracks") {
                                    SearchSectionHeader(title: "Server Catalog Songs")
                                    ForEach(catalogResults.songs) { remoteSong in
                                        RemoteSongRow(
                                            song: remoteSong,
                                            isDownloading: downloadingIds.contains(remoteSong.id),
                                            isCurrentlyPlaying: player.currentTrack?.title == remoteSong.title
                                        ) {
                                            playAndDownload(song: remoteSong)
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                                
                                // Server Catalog Albums
                                if !catalogResults.albums.isEmpty && (selectedFilter == "All" || selectedFilter == "Albums") {
                                    SearchSectionHeader(title: "Server Catalog Albums")
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(catalogResults.albums) { remoteAlbum in
                                                RemoteAlbumCard(
                                                    album: remoteAlbum,
                                                    isDownloading: downloadingIds.contains(remoteAlbum.id)
                                                ) {
                                                    playAndDownload(album: remoteAlbum)
                                                }
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
            .overlay(alignment: .bottom) {
                if let notice = actionNotification {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(DowntifyColor.primary)
                        Text(notice)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.88))
                    .clipShape(Capsule())
                    .shadow(radius: 6)
                    .padding(.bottom, 65)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: actionNotification)
                }
            }
        }
    }
    
    // MARK: - Actions: Download & Play for Remote Items
    
    private func playAndDownload(song: RemoteSong) {
        actionNotification = "Downloading & playing \(song.title)..."
        downloadingIds.insert(song.id)
        
        Task {
            // Warm cache and resolve videoId
            let videoId = await DowntifyAPI.shared.resolveStreamVideoId(for: song)
            await DowntifyAPI.shared.prefetchStream(videoId: videoId)
            
            let playable = Track(remote: song, streamVideoId: videoId)
            if let coverUrl = URL(string: song.coverUrl), !song.coverUrl.isEmpty {
                DowntifyAPI.shared.registerStreamCover(trackId: playable.id, url: coverUrl)
            }
            
            await MainActor.run {
                player.play(track: playable, context: "Search: \(song.title)")
            }
            
            // Queue download on server in background
            do {
                try await DowntifyAPI.shared.downloadSongs([song])
            } catch {
                print("[Search] Download queue failed on server: \(error)")
            }
            
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                if actionNotification == "Downloading & playing \(song.title)..." {
                    actionNotification = nil
                }
            }
        }
    }
    
    private func playAndDownload(album: RemoteAlbum) {
        actionNotification = "Downloading album '\(album.title)' & playing..."
        downloadingIds.insert(album.id)
        
        Task {
            do {
                let tracks = try await DowntifyAPI.shared.downloadAlbum(album)
                if let firstTrack = tracks.first {
                    let videoId = await DowntifyAPI.shared.resolveStreamVideoId(for: firstTrack)
                    await DowntifyAPI.shared.prefetchStream(videoId: videoId)
                    
                    let playable = Track(remote: firstTrack, streamVideoId: videoId)
                    let albumArt = firstTrack.coverUrl.isEmpty ? album.coverUrl : firstTrack.coverUrl
                    if let coverUrl = URL(string: albumArt), !albumArt.isEmpty {
                        DowntifyAPI.shared.registerStreamCover(trackId: playable.id, url: coverUrl)
                    }
                    
                    var queueTracks: [Track] = [playable]
                    for other in tracks.dropFirst() {
                        let vid = StreamVideo.videoId(of: other) ?? other.id
                        let p = Track(remote: other, streamVideoId: vid)
                        let art = other.coverUrl.isEmpty ? album.coverUrl : other.coverUrl
                        if let cUrl = URL(string: art), !art.isEmpty {
                            DowntifyAPI.shared.registerStreamCover(trackId: p.id, url: cUrl)
                        }
                        queueTracks.append(p)
                    }
                    
                    await MainActor.run {
                        player.play(queue: queueTracks, startingAt: 0, context: "Album: \(album.title)")
                    }
                } else {
                    // If no tracks returned, search catalog for album tracks
                    let searchRes = try? await DowntifyAPI.shared.searchCatalog(query: "\(album.artist) \(album.title)")
                    if let first = searchRes?.songs.first {
                        playAndDownload(song: first)
                    }
                }
            } catch {
                print("[Search] Download album failed: \(error)")
            }
            
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            await MainActor.run {
                if actionNotification == "Downloading album '\(album.title)' & playing..." {
                    actionNotification = nil
                }
            }
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
    var isDownloading: Bool = false
    var isCurrentlyPlaying: Bool = false
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
                        .foregroundColor(isCurrentlyPlaying ? DowntifyColor.primary : DowntifyColor.textPrimary)
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
                
                if isDownloading {
                    ProgressView()
                        .tint(DowntifyColor.primary)
                        .scaleEffect(0.85)
                } else if isCurrentlyPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(DowntifyColor.primary)
                        .font(.system(size: 18))
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(DowntifyColor.primary)
                        .font(.system(size: 22))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct RemoteAlbumCard: View {
    let album: RemoteAlbum
    var isDownloading: Bool = false
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    AuthenticatedArtworkImage(
                        url: URL(string: album.coverUrl),
                        size: 120,
                        cornerRadius: DowntifyShape.coverRadius
                    )
                    
                    // Download & play badge
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.75))
                            .frame(width: 28, height: 28)
                        
                        if isDownloading {
                            ProgressView()
                                .tint(DowntifyColor.primary)
                                .scaleEffect(0.65)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(DowntifyColor.primary)
                        }
                    }
                    .padding(6)
                }
                
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
