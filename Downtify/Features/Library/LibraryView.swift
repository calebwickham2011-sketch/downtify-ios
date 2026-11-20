import SwiftUI

// MARK: - Sort-key helper (strips leading "The ", case-insensitive)
private func sortKey(_ raw: String) -> String {
    let lower = raw.lowercased()
    if lower.hasPrefix("the ") {
        return String(raw.dropFirst(4))
    }
    return raw
}

// MARK: - Library Section Enum
private enum LibrarySection: String, CaseIterable, Identifiable {
    case recentlyAdded = "Recently Added"
    case albums        = "Albums"
    case playlists     = "Playlists"
    case tracks        = "Tracks"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .recentlyAdded: return "clock.fill"
        case .albums:        return "square.stack.fill"
        case .playlists:     return "music.note.list"
        case .tracks:        return "music.note"
        }
    }
}

// MARK: - Alpha-index sidebar letters
private let alphabet: [String] = ["#"] + (65...90).map { String(UnicodeScalar($0)!) }

// MARK: - LibraryView
public struct LibraryView: View {
    @ObservedObject var theme   = ThemeManager.shared
    @ObservedObject var library = LibraryService.shared

    @State private var activeSection: LibrarySection = .recentlyAdded
    @State private var showSettings = false

    // Alpha-scroll state
    @State private var isDraggingIndex = false
    @State private var hoveredLetter: String = ""

    // Scroll proxy anchors
    @State private var scrollProxy: ScrollViewProxy? = nil

    public init() {}

    // MARK: Sorted data

    private var sortedAlbums: [Album] {
        library.albums.sorted { sortKey($0.title) < sortKey($1.title) }
    }

    private var sortedPlaylists: [Playlist] {
        library.playlists.sorted { sortKey($0.title) < sortKey($1.title) }
    }

    private var sortedTracks: [Track] {
        library.tracks.sorted { sortKey($0.displayTitle) < sortKey($1.displayTitle) }
    }

    /// All items sorted by date added (newest first) — albums only for display
    private var recentAlbums: [Album] {
        // We use album title sort as proxy; ideally the server returns a createdAt field.
        // Sort descending by album ID (server usually returns newest first) — adapt if model gains a date field.
        library.albums.reversed()
    }

    private var recentTracks: [Track] {
        library.tracks.reversed()
    }

    // MARK: Alpha sections for sidebar

    private func albumsGrouped() -> [(letter: String, items: [Album])] {
        groupByLetter(sortedAlbums) { sortKey($0.title) }
    }

    private func tracksGrouped() -> [(letter: String, items: [Track])] {
        groupByLetter(sortedTracks) { sortKey($0.displayTitle) }
    }

    private func playlistsGrouped() -> [(letter: String, items: [Playlist])] {
        groupByLetter(sortedPlaylists) { sortKey($0.title) }
    }

    private func groupByLetter<T>(_ items: [T], key: (T) -> String) -> [(letter: String, items: [T])] {
        var dict: [String: [T]] = [:]
        for item in items {
            let first = key(item).first.map { c -> String in
                let s = String(c).uppercased()
                return s.first?.isLetter == true ? s : "#"
            } ?? "#"
            dict[first, default: []].append(item)
        }
        return dict.keys.sorted().map { letter in (letter: letter, items: dict[letter]!) }
    }

    // MARK: Body

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .trailing) {
                VStack(spacing: 0) {
                    // Section picker — horizontal scroll pills
                    sectionPicker

                    // Main scrollable content
                    ScrollViewReader { proxy in
                        ScrollView {
                            Group {
                                switch activeSection {
                                case .recentlyAdded: recentlyAddedContent
                                case .albums:        alphaContent(groups: albumsGrouped(), rowBuilder: albumRow)
                                case .playlists:     alphaContent(groups: playlistsGrouped(), rowBuilder: playlistRow)
                                case .tracks:        alphaContent(groups: tracksGrouped(), rowBuilder: trackRow)
                                }
                            }
                            .padding(.top, 8)
                            Spacer(minLength: 100)
                        }
                        .onAppear { scrollProxy = proxy }
                        .onChange(of: activeSection) { scrollProxy = proxy }
                    }
                }
                .background(theme.currentBackground.ignoresSafeArea())

                // Alpha index sidebar (only for alphabetical sections)
                if activeSection != .recentlyAdded {
                    alphaSidebar
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: DowntifyIcons.settings)
                            .foregroundColor(DowntifyColor.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .refreshable { await library.refreshLibrary() }
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibrarySection.allCases) { section in
                    Button(action: { withAnimation(.spring(response: 0.3)) { activeSection = section } }) {
                        Label(section.rawValue, systemImage: section.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                activeSection == section
                                    ? DowntifyColor.primary
                                    : DowntifyColor.surface
                            )
                            .foregroundColor(
                                activeSection == section ? .white : DowntifyColor.textSecondary
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Recently Added Content

    private var recentlyAddedContent: some View {
        LazyVStack(spacing: 0) {
            // Show Liked Songs pinned at top
            likedSongsRow

            // Recent tracks (server order = newest first)
            ForEach(recentTracks) { track in
                trackRow(track)
                    .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Alpha Grouped Content

    @ViewBuilder
    private func alphaContent<T: Identifiable>(
        groups: [(letter: String, items: [T])],
        rowBuilder: @escaping (T) -> some View
    ) -> some View {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
            ForEach(groups, id: \.letter) { group in
                Section {
                    ForEach(group.items) { item in
                        rowBuilder(item)
                            .padding(.vertical, 4)
                    }
                } header: {
                    Text(group.letter)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(DowntifyColor.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.currentBackground.opacity(0.95))
                        .id("header_\(group.letter)")
                }
            }
        }
    }

    // MARK: - Alpha Sidebar

    private var alphaSidebar: some View {
        VStack(spacing: 0) {
            ForEach(alphabet, id: \.self) { letter in
                Text(letter)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(
                        hoveredLetter == letter && isDraggingIndex
                            ? DowntifyColor.primary
                            : DowntifyColor.textSecondary
                    )
                    .frame(width: 18, height: 14)
            }
        }
        .padding(.trailing, 4)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDraggingIndex = true
                    let totalHeight = CGFloat(alphabet.count) * 14
                    let idx = max(0, min(alphabet.count - 1, Int(value.location.y / totalHeight * CGFloat(alphabet.count))))
                    let letter = alphabet[idx]
                    if letter != hoveredLetter {
                        hoveredLetter = letter
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        scrollProxy?.scrollTo("header_\(letter)", anchor: .top)
                    }
                }
                .onEnded { _ in
                    isDraggingIndex = false
                    hoveredLetter = ""
                }
        )
    }

    // MARK: - Row Builders

    @ViewBuilder
    private var likedSongsRow: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: DowntifyShape.coverRadius, style: .continuous)
                .fill(DowntifyColor.liked.gradient)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: DowntifyIcons.heartFill)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Liked Songs")
                    .font(DowntifyFont.cardTitle)
                    .foregroundColor(DowntifyColor.textPrimary)
                Text("Playlist • \(library.likedTrackIds.count) songs")
                    .font(DowntifyFont.cardSubtitle)
                    .foregroundColor(DowntifyColor.textSecondary)
            }

            Spacer()

            Image(systemName: "pin.fill")
                .font(.system(size: 12))
                .foregroundColor(DowntifyColor.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func albumRow(_ album: Album) -> some View {
        NavigationLink(destination: AlbumDetailView(album: album)) {
            HStack(spacing: 14) {
                let coverUrl = album.coverTrackId.flatMap { DowntifyAPI.shared.coverUrl(trackId: $0, size: 150) }
                AuthenticatedArtworkImage(url: coverUrl, size: 56, cornerRadius: DowntifyShape.coverRadius)

                VStack(alignment: .leading, spacing: 4) {
                    Text(album.title)
                        .font(DowntifyFont.cardTitle)
                        .foregroundColor(DowntifyColor.textPrimary)
                        .lineLimit(1)
                    Text("Album • \(album.artist)")
                        .font(DowntifyFont.cardSubtitle)
                        .foregroundColor(DowntifyColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DowntifyColor.textTertiary)
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func playlistRow(_ playlist: Playlist) -> some View {
        NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
            HStack(spacing: 14) {
                let coverUrl = DowntifyAPI.shared.playlistCoverUrl(path: playlist.cover)
                AuthenticatedArtworkImage(url: coverUrl, size: 56, cornerRadius: DowntifyShape.coverRadius)

                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.title)
                        .font(DowntifyFont.cardTitle)
                        .foregroundColor(DowntifyColor.textPrimary)
                        .lineLimit(1)
                    Text("Playlist • \(playlist.trackIds.count) tracks")
                        .font(DowntifyFont.cardSubtitle)
                        .foregroundColor(DowntifyColor.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DowntifyColor.textTertiary)
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func trackRow(_ track: Track) -> some View {
        Button(action: {
            let idx = library.tracks.firstIndex(where: { $0.id == track.id }) ?? 0
            AudioPlayerManager.shared.play(queue: library.tracks, startingAt: idx)
        }) {
            HStack(spacing: 14) {
                let coverUrl = DowntifyAPI.shared.coverUrl(trackId: track.id, size: 100)
                AuthenticatedArtworkImage(url: coverUrl, size: 56, cornerRadius: DowntifyShape.coverRadius)

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.displayTitle)
                        .font(DowntifyFont.cardTitle)
                        .foregroundColor(DowntifyColor.textPrimary)
                        .lineLimit(1)
                    Text(track.displayArtist)
                        .font(DowntifyFont.cardSubtitle)
                        .foregroundColor(DowntifyColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "play.fill")
                    .font(.system(size: 12))
                    .foregroundColor(DowntifyColor.textTertiary)
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}
