import SwiftUI

// MARK: - Sort-key helper (strips leading "The ", case-insensitive)
public func sortKey(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()
    if lower.hasPrefix("the ") {
        return String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return trimmed
}

// MARK: - Alphabet for index scroller
public let alphabetLetters: [String] = ["#"] + (65...90).map { String(UnicodeScalar($0)!) }

// MARK: - Submenu Back Button (strictly just "<")
public struct CustomSubmenuBackButton: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(DowntifyColor.primary)
                .frame(width: 36, height: 36, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

// MARK: - Alpha Index Scroller
public struct AlphaIndexSidebar: View {
    public let proxy: ScrollViewProxy
    @State private var hoveredLetter: String = ""
    @State private var isDragging: Bool = false

    public init(proxy: ScrollViewProxy) {
        self.proxy = proxy
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(alphabetLetters, id: \.self) { letter in
                Text(letter)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(
                        hoveredLetter == letter && isDragging
                            ? DowntifyColor.primary
                            : DowntifyColor.textSecondary
                    )
                    .frame(width: 20, height: 14)
            }
        }
        .padding(.trailing, 2)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDragging = true
                    let totalHeight = CGFloat(alphabetLetters.count) * 14
                    let idx = max(0, min(alphabetLetters.count - 1, Int(value.location.y / totalHeight * CGFloat(alphabetLetters.count))))
                    let letter = alphabetLetters[idx]
                    if letter != hoveredLetter {
                        hoveredLetter = letter
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        proxy.scrollTo("header_\(letter)", anchor: .top)
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    hoveredLetter = ""
                }
        )
    }
}

// MARK: - Grouping Helper
public func groupAlphabetically<T>(_ items: [T], key: (T) -> String) -> [(letter: String, items: [T])] {
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

// MARK: - Customizable Menu Item Types
public enum LibraryMenuItemType: String, CaseIterable, Codable, Identifiable {
    case playlists     = "Playlists"
    case artists       = "Artists"
    case albums        = "Albums"
    case tracks        = "Songs"
    case recentlyAdded = "Recently Added"
    case downloaded    = "Downloaded"
    case likedSongs    = "Liked Songs"
    case podcasts      = "Podcasts"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .playlists: return "Playlists"
        case .artists: return "Artists"
        case .albums: return "Albums"
        case .tracks: return "Songs"
        case .recentlyAdded: return "Recently Added"
        case .downloaded: return "Downloaded"
        case .likedSongs: return "Liked Songs"
        case .podcasts: return "Podcasts"
        }
    }

    public var systemImage: String {
        switch self {
        case .playlists: return "music.note.list"
        case .artists: return "music.mic"
        case .albums: return "square.stack.fill"
        case .tracks: return "music.note"
        case .recentlyAdded: return "clock.fill"
        case .downloaded: return "arrow.down.circle.fill"
        case .likedSongs: return "heart.fill"
        case .podcasts: return "antenna.radiowaves.left.and.right"
        }
    }

    public var iconColor: Color {
        switch self {
        case .playlists: return .pink
        case .artists: return .blue
        case .albums: return .orange
        case .tracks: return .teal
        case .recentlyAdded: return .purple
        case .downloaded: return .green
        case .likedSongs: return .red
        case .podcasts: return .indigo
        }
    }
}

public struct LibraryMenuOption: Codable, Identifiable, Equatable {
    public var id: String { type.rawValue }
    public let type: LibraryMenuItemType
    public var isEnabled: Bool

    public init(type: LibraryMenuItemType, isEnabled: Bool = true) {
        self.type = type
        self.isEnabled = isEnabled
    }
}

// MARK: - Library Menu Preferences Store
@MainActor
public final class LibraryPreferences: ObservableObject {
    public static let shared = LibraryPreferences()
    private let key = "downtify_library_menu_options_v3"

    @Published public var options: [LibraryMenuOption] = []

    private init() {
        load()
    }

    public func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([LibraryMenuOption].self, from: data),
           !saved.isEmpty {
            var result = saved
            for item in LibraryMenuItemType.allCases {
                if !result.contains(where: { $0.type == item }) {
                    result.append(LibraryMenuOption(type: item, isEnabled: true))
                }
            }
            self.options = result
        } else {
            resetToDefaults()
        }
    }

    public func save() {
        if let data = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    public func resetToDefaults() {
        self.options = [
            LibraryMenuOption(type: .playlists, isEnabled: true),
            LibraryMenuOption(type: .artists, isEnabled: true),
            LibraryMenuOption(type: .albums, isEnabled: true),
            LibraryMenuOption(type: .tracks, isEnabled: true),
            LibraryMenuOption(type: .recentlyAdded, isEnabled: true),
            LibraryMenuOption(type: .downloaded, isEnabled: true),
            LibraryMenuOption(type: .likedSongs, isEnabled: true),
            LibraryMenuOption(type: .podcasts, isEnabled: true),
        ]
        save()
    }

    public func moveUp(item: LibraryMenuOption) {
        guard let index = options.firstIndex(where: { $0.id == item.id }), index > 0 else { return }
        options.swapAt(index, index - 1)
        save()
    }

    public func moveDown(item: LibraryMenuOption) {
        guard let index = options.firstIndex(where: { $0.id == item.id }), index < options.count - 1 else { return }
        options.swapAt(index, index + 1)
        save()
    }

    public func toggle(item: LibraryMenuOption) {
        guard let index = options.firstIndex(where: { $0.id == item.id }) else { return }
        options[index].isEnabled.toggle()
        save()
    }
}

// MARK: - Main Library View (Full Customizable Menu Root)
public struct LibraryView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var library = LibraryService.shared
    @ObservedObject var prefs = LibraryPreferences.shared
    @ObservedObject var downloadManager = OfflineDownloadManager.shared

    @State private var isEditing = false
    @State private var showSettings = false

    public init() {}

    private var enabledOptions: [LibraryMenuOption] {
        prefs.options.filter { $0.isEnabled }
    }

    private var recentAlbums: [Album] {
        library.albums.sorted { $0.added > $1.added }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isEditing {
                        // MARK: Customizable Menu Editor
                        customizableMenuEditor
                    } else {
                        // MARK: Normal Customizable Menu Rows
                        customizableMenuRows

                        // MARK: Apple Music-style "Recently Added" Shelf
                        if !recentAlbums.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Recently Added")
                                        .font(DowntifyFont.sectionTitle)
                                        .foregroundColor(DowntifyColor.textPrimary)
                                    Spacer()
                                    NavigationLink(destination: LibraryRecentlyAddedView()) {
                                        Text("See All")
                                            .font(DowntifyFont.caption)
                                            .foregroundColor(DowntifyColor.primary)
                                    }
                                }
                                .padding(.horizontal, 16)

                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: 14),
                                        GridItem(.flexible(), spacing: 14)
                                    ],
                                    spacing: 16
                                ) {
                                    ForEach(recentAlbums.prefix(6)) { album in
                                        NavigationLink(destination: AlbumDetailView(album: album)) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                let coverUrl = album.coverTrackId.flatMap {
                                                    DowntifyAPI.shared.coverUrl(trackId: $0, size: 250)
                                                }
                                                AuthenticatedArtworkImage(
                                                    url: coverUrl,
                                                    size: 160,
                                                    cornerRadius: DowntifyShape.coverRadius
                                                )
                                                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)

                                                Text(album.title)
                                                    .font(DowntifyFont.cardTitle)
                                                    .foregroundColor(DowntifyColor.textPrimary)
                                                    .lineLimit(1)

                                                Text(album.artist)
                                                    .font(DowntifyFont.cardSubtitle)
                                                    .foregroundColor(DowntifyColor.textSecondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 8)
            }
            .background(theme.currentBackground.ignoresSafeArea())
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button("Reset") {
                            withAnimation(.spring(response: 0.3)) {
                                prefs.resetToDefaults()
                            }
                        }
                        .foregroundColor(.red)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button(isEditing ? "Done" : "Edit") {
                            withAnimation(.spring(response: 0.35)) {
                                isEditing.toggle()
                                if !isEditing {
                                    prefs.save()
                                }
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DowntifyColor.primary)

                        if !isEditing {
                            Button(action: { showSettings = true }) {
                                Image(systemName: DowntifyIcons.settings)
                                    .foregroundColor(DowntifyColor.textPrimary)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .refreshable {
                await library.refreshLibrary()
            }
        }
    }

    // MARK: - Customizable Menu Rows (Normal Mode)
    private var customizableMenuRows: some View {
        VStack(spacing: 0) {
            ForEach(enabledOptions) { option in
                NavigationLink(destination: destinationView(for: option.type)) {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(option.type.iconColor.opacity(0.2))
                                .frame(width: 34, height: 34)
                            Image(systemName: option.type.systemImage)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(option.type.iconColor)
                        }

                        Text(option.type.title)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(DowntifyColor.textPrimary)

                        Spacer()

                        itemCountBadge(for: option.type)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DowntifyColor.textTertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 66)
            }
        }
        .background(DowntifyColor.surface.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: - Customizable Menu Editor
    private var customizableMenuEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Customize Library Menu")
                    .font(DowntifyFont.sectionTitle)
                    .foregroundColor(DowntifyColor.textPrimary)
                Text("Tap to check or uncheck options. Use the up and down arrows to reorder.")
                    .font(DowntifyFont.caption)
                    .foregroundColor(DowntifyColor.textSecondary)
            }
            .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(prefs.options.enumerated()), id: \.element.id) { index, option in
                    HStack(spacing: 14) {
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                prefs.toggle(item: option)
                            }
                        } label: {
                            Image(systemName: option.isEnabled ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundColor(option.isEnabled ? DowntifyColor.primary : DowntifyColor.textTertiary)
                        }
                        .buttonStyle(.plain)

                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(option.type.iconColor.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Image(systemName: option.type.systemImage)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(option.type.iconColor)
                        }

                        Text(option.type.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(option.isEnabled ? DowntifyColor.textPrimary : DowntifyColor.textTertiary)

                        Spacer()

                        // Reorder buttons
                        HStack(spacing: 8) {
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    prefs.moveUp(item: option)
                                }
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(index > 0 ? DowntifyColor.textSecondary : DowntifyColor.textTertiary.opacity(0.3))
                                    .frame(width: 30, height: 30)
                            }
                            .disabled(index == 0)

                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    prefs.moveDown(item: option)
                                }
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(index < prefs.options.count - 1 ? DowntifyColor.textSecondary : DowntifyColor.textTertiary.opacity(0.3))
                                    .frame(width: 30, height: 30)
                            }
                            .disabled(index == prefs.options.count - 1)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Divider()
                        .padding(.leading, 50)
                }
            }
            .background(DowntifyColor.surface.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func itemCountBadge(for type: LibraryMenuItemType) -> some View {
        let count: Int = {
            switch type {
            case .playlists: return library.playlists.count
            case .artists: return library.artists.count
            case .albums: return library.albums.count
            case .tracks: return library.tracks.count
            case .recentlyAdded: return library.tracks.count
            case .downloaded: return downloadManager.downloadedTrackIds.count
            case .likedSongs: return library.likedTrackIds.count
            case .podcasts: return 0
            }
        }()

        if count > 0 {
            Text("\(count)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DowntifyColor.textTertiary)
        }
    }

    @ViewBuilder
    private func destinationView(for type: LibraryMenuItemType) -> some View {
        switch type {
        case .playlists:     LibraryPlaylistsView()
        case .artists:       LibraryArtistsView()
        case .albums:        LibraryAlbumsView()
        case .tracks:        LibraryTracksView()
        case .recentlyAdded: LibraryRecentlyAddedView()
        case .downloaded:    LibraryDownloadedView()
        case .likedSongs:    LibraryLikedSongsView()
        case .podcasts:      LibraryPodcastsSubmenuView()
        }
    }
}

// MARK: - SUBMENU: Recently Added (Date Added Sort, Back Button "<")
public struct LibraryRecentlyAddedView: View {
    @ObservedObject var library = LibraryService.shared
    @State private var displayMode: Int = 0 // 0: Tracks, 1: Albums

    public init() {}

    private var recentTracks: [Track] {
        library.tracks.sorted { $0.added > $1.added }
    }

    private var recentAlbums: [Album] {
        library.albums.sorted { $0.added > $1.added }
    }

    public var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $displayMode) {
                Text("Tracks").tag(0)
                Text("Albums").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            ScrollView {
                if displayMode == 0 {
                    LazyVStack(spacing: 4) {
                        ForEach(recentTracks) { track in
                            Button(action: {
                                let idx = recentTracks.firstIndex(where: { $0.id == track.id }) ?? 0
                                AudioPlayerManager.shared.play(queue: recentTracks, startingAt: idx, context: "Recently Added")
                            }) {
                                HStack(spacing: 14) {
                                    let coverUrl = DowntifyAPI.shared.coverUrl(trackId: track.id, size: 100)
                                    AuthenticatedArtworkImage(url: coverUrl, size: 52, cornerRadius: DowntifyShape.coverRadius)

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
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 14),
                            GridItem(.flexible(), spacing: 14)
                        ],
                        spacing: 16
                    ) {
                        ForEach(recentAlbums) { album in
                            NavigationLink(destination: AlbumDetailView(album: album)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    let coverUrl = album.coverTrackId.flatMap {
                                        DowntifyAPI.shared.coverUrl(trackId: $0, size: 250)
                                    }
                                    AuthenticatedArtworkImage(url: coverUrl, size: 160, cornerRadius: DowntifyShape.coverRadius)
                                        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)

                                    Text(album.title)
                                        .font(DowntifyFont.cardTitle)
                                        .foregroundColor(DowntifyColor.textPrimary)
                                        .lineLimit(1)
                                    Text(album.artist)
                                        .font(DowntifyFont.cardSubtitle)
                                        .foregroundColor(DowntifyColor.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                Spacer(minLength: 100)
            }
        }
        .background(DowntifyColor.backgroundDark.ignoresSafeArea())
        .navigationTitle("Recently Added")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CustomSubmenuBackButton()
            }
        }
    }
}

// MARK: - SUBMENU: Albums (Alphabetical, "The" stripped, Apple letters, Back Button "<")
public struct LibraryAlbumsView: View {
    @ObservedObject var library = LibraryService.shared

    public init() {}

    private var sortedAlbums: [Album] {
        library.albums.sorted { sortKey($0.title) < sortKey($1.title) }
    }

    private var groupedAlbums: [(letter: String, items: [Album])] {
        groupAlphabetically(sortedAlbums) { sortKey($0.title) }
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(groupedAlbums, id: \.letter) { group in
                            Section {
                                ForEach(group.items) { album in
                                    NavigationLink(destination: AlbumDetailView(album: album)) {
                                        HStack(spacing: 14) {
                                            let coverUrl = album.coverTrackId.flatMap {
                                                DowntifyAPI.shared.coverUrl(trackId: $0, size: 150)
                                            }
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
                                        .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                Text(group.letter)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(DowntifyColor.textSecondary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(DowntifyColor.backgroundDark.opacity(0.95))
                                    .id("header_\(group.letter)")
                            }
                        }
                    }
                    .padding(.top, 8)
                    Spacer(minLength: 100)
                }

                // Apple letters sidebar
                AlphaIndexSidebar(proxy: proxy)
            }
        }
        .background(DowntifyColor.backgroundDark.ignoresSafeArea())
        .navigationTitle("Albums")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CustomSubmenuBackButton()
            }
        }
    }
}

// MARK: - SUBMENU: Playlists (Alphabetical, "The" stripped, Apple letters, Back Button "<")
public struct LibraryPlaylistsView: View {
    @ObservedObject var library = LibraryService.shared

    public init() {}

    private var sortedPlaylists: [Playlist] {
        library.playlists.sorted { sortKey($0.title) < sortKey($1.title) }
    }

    private var groupedPlaylists: [(letter: String, items: [Playlist])] {
        groupAlphabetically(sortedPlaylists) { sortKey($0.title) }
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(groupedPlaylists, id: \.letter) { group in
                            Section {
                                ForEach(group.items) { playlist in
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
                                        .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                Text(group.letter)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(DowntifyColor.textSecondary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(DowntifyColor.backgroundDark.opacity(0.95))
                                    .id("header_\(group.letter)")
                            }
                        }
                    }
                    .padding(.top, 8)
                    Spacer(minLength: 100)
                }

                AlphaIndexSidebar(proxy: proxy)
            }
        }
        .background(DowntifyColor.backgroundDark.ignoresSafeArea())
        .navigationTitle("Playlists")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CustomSubmenuBackButton()
            }
        }
    }
}

// MARK: - SUBMENU: Tracks (Alphabetical, "The" stripped, Apple letters, Back Button "<")
public struct LibraryTracksView: View {
    @ObservedObject var library = LibraryService.shared

    public init() {}

    private var sortedTracks: [Track] {
        library.tracks.sorted { sortKey($0.displayTitle) < sortKey($1.displayTitle) }
    }

    private var groupedTracks: [(letter: String, items: [Track])] {
        groupAlphabetically(sortedTracks) { sortKey($0.displayTitle) }
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    // Quick Action: Shuffle All
                    if !sortedTracks.isEmpty {
                        Button {
                            AudioPlayerManager.shared.play(queue: sortedTracks.shuffled(), startingAt: 0, context: "All Songs")
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Shuffle All (\(sortedTracks.count) songs)")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(DowntifyColor.primary)
                            .cornerRadius(22)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                    }

                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(groupedTracks, id: \.letter) { group in
                            Section {
                                ForEach(group.items) { track in
                                    Button(action: {
                                        let idx = sortedTracks.firstIndex(where: { $0.id == track.id }) ?? 0
                                        AudioPlayerManager.shared.play(queue: sortedTracks, startingAt: idx, context: "All Songs")
                                    }) {
                                        HStack(spacing: 14) {
                                            let coverUrl = DowntifyAPI.shared.coverUrl(trackId: track.id, size: 100)
                                            AuthenticatedArtworkImage(url: coverUrl, size: 52, cornerRadius: DowntifyShape.coverRadius)

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
                                        .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                Text(group.letter)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(DowntifyColor.textSecondary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(DowntifyColor.backgroundDark.opacity(0.95))
                                    .id("header_\(group.letter)")
                            }
                        }
                    }
                    .padding(.top, 4)
                    Spacer(minLength: 100)
                }

                AlphaIndexSidebar(proxy: proxy)
            }
        }
        .background(DowntifyColor.backgroundDark.ignoresSafeArea())
        .navigationTitle("Songs")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CustomSubmenuBackButton()
            }
        }
    }
}

// MARK: - SUBMENU: Artists (Alphabetical, "The" stripped, Apple letters, Back Button "<")
public struct LibraryArtistsView: View {
    @ObservedObject var library = LibraryService.shared

    public init() {}

    private var sortedArtists: [Artist] {
        library.artists.sorted { sortKey($0.name) < sortKey($1.name) }
    }

    private var groupedArtists: [(letter: String, items: [Artist])] {
        groupAlphabetically(sortedArtists) { sortKey($0.name) }
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(groupedArtists, id: \.letter) { group in
                            Section {
                                ForEach(group.items) { artist in
                                    HStack(spacing: 14) {
                                        let coverUrl = artist.coverTrackId.flatMap {
                                            DowntifyAPI.shared.coverUrl(trackId: $0, size: 150)
                                        }
                                        AuthenticatedArtworkImage(url: coverUrl, size: 56, cornerRadius: 28)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(artist.name)
                                                .font(DowntifyFont.cardTitle)
                                                .foregroundColor(DowntifyColor.textPrimary)
                                            Text("\(artist.albums.count) albums • \(artist.tracks.count) tracks")
                                                .font(DowntifyFont.cardSubtitle)
                                                .foregroundColor(DowntifyColor.textSecondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(DowntifyColor.textTertiary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                }
                            } header: {
                                Text(group.letter)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(DowntifyColor.textSecondary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(DowntifyColor.backgroundDark.opacity(0.95))
                                    .id("header_\(group.letter)")
                            }
                        }
                    }
                    .padding(.top, 8)
                    Spacer(minLength: 100)
                }

                AlphaIndexSidebar(proxy: proxy)
            }
        }
        .background(DowntifyColor.backgroundDark.ignoresSafeArea())
        .navigationTitle("Artists")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CustomSubmenuBackButton()
            }
        }
    }
}

// MARK: - SUBMENU: Downloaded (Offline Tracks, Alphabetical, Back Button "<")
public struct LibraryDownloadedView: View {
    @ObservedObject var library = LibraryService.shared
    @ObservedObject var downloadManager = OfflineDownloadManager.shared

    public init() {}

    private var downloadedTracks: [Track] {
        library.tracks.filter { downloadManager.isDownloaded(trackId: $0.id) }
            .sorted { sortKey($0.displayTitle) < sortKey($1.displayTitle) }
    }

    private var groupedDownloaded: [(letter: String, items: [Track])] {
        groupAlphabetically(downloadedTracks) { sortKey($0.displayTitle) }
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    if downloadedTracks.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 48))
                                .foregroundColor(DowntifyColor.textTertiary)
                            Text("No Downloaded Music")
                                .font(DowntifyFont.sectionTitle)
                                .foregroundColor(DowntifyColor.textPrimary)
                            Text("Download songs and albums to listen when you're offline.")
                                .font(DowntifyFont.body)
                                .foregroundColor(DowntifyColor.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 80)
                    } else {
                        // Quick action: Play Downloaded
                        Button {
                            AudioPlayerManager.shared.play(queue: downloadedTracks.shuffled(), startingAt: 0, context: "Downloaded Music")
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 15))
                                Text("Play Downloaded (\(downloadedTracks.count) songs)")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(DowntifyColor.primary)
                            .cornerRadius(22)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }

                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                            ForEach(groupedDownloaded, id: \.letter) { group in
                                Section {
                                    ForEach(group.items) { track in
                                        Button(action: {
                                            let idx = downloadedTracks.firstIndex(where: { $0.id == track.id }) ?? 0
                                            AudioPlayerManager.shared.play(queue: downloadedTracks, startingAt: idx, context: "Downloaded Music")
                                        }) {
                                            HStack(spacing: 14) {
                                                let coverUrl = DowntifyAPI.shared.coverUrl(trackId: track.id, size: 100)
                                                AuthenticatedArtworkImage(url: coverUrl, size: 52, cornerRadius: DowntifyShape.coverRadius)

                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(track.displayTitle)
                                                        .font(DowntifyFont.cardTitle)
                                                        .foregroundColor(DowntifyColor.textPrimary)
                                                        .lineLimit(1)
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "arrow.down.circle.fill")
                                                            .font(.system(size: 10))
                                                            .foregroundColor(DowntifyColor.primary)
                                                        Text(track.displayArtist)
                                                            .font(DowntifyFont.cardSubtitle)
                                                            .foregroundColor(DowntifyColor.textSecondary)
                                                            .lineLimit(1)
                                                    }
                                                }

                                                Spacer()

                                                Image(systemName: "play.fill")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(DowntifyColor.textTertiary)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } header: {
                                    Text(group.letter)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(DowntifyColor.textSecondary)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(DowntifyColor.backgroundDark.opacity(0.95))
                                        .id("header_\(group.letter)")
                                }
                            }
                        }
                    }

                    Spacer(minLength: 100)
                }

                if !downloadedTracks.isEmpty {
                    AlphaIndexSidebar(proxy: proxy)
                }
            }
        }
        .background(DowntifyColor.backgroundDark.ignoresSafeArea())
        .navigationTitle("Downloaded")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CustomSubmenuBackButton()
            }
        }
    }
}

// MARK: - SUBMENU: Liked Songs (Alphabetical, "The" stripped, Back Button "<")
public struct LibraryLikedSongsView: View {
    @ObservedObject var library = LibraryService.shared

    public init() {}

    private var likedTracks: [Track] {
        library.tracks.filter { library.likedTrackIds.contains($0.id) }
            .sorted { sortKey($0.displayTitle) < sortKey($1.displayTitle) }
    }

    private var groupedLiked: [(letter: String, items: [Track])] {
        groupAlphabetically(likedTracks) { sortKey($0.displayTitle) }
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    // Hero card
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: DowntifyShape.coverRadius, style: .continuous)
                            .fill(DowntifyColor.liked.gradient)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: DowntifyIcons.heartFill)
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Liked Songs")
                                .font(DowntifyFont.sectionTitle)
                                .foregroundColor(DowntifyColor.textPrimary)
                            Text("\(likedTracks.count) songs")
                                .font(DowntifyFont.body)
                                .foregroundColor(DowntifyColor.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    // Shuffle & Play buttons
                    if !likedTracks.isEmpty {
                        HStack(spacing: 12) {
                            Button {
                                AudioPlayerManager.shared.play(queue: likedTracks, startingAt: 0, context: "Liked Songs")
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                    Text("Play")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(DowntifyColor.primary)
                                .cornerRadius(21)
                            }

                            Button {
                                AudioPlayerManager.shared.play(queue: likedTracks.shuffled(), startingAt: 0, context: "Liked Songs")
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "shuffle")
                                    Text("Shuffle")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(DowntifyColor.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(DowntifyColor.surface)
                                .cornerRadius(21)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                            ForEach(groupedLiked, id: \.letter) { group in
                                Section {
                                    ForEach(group.items) { track in
                                        Button(action: {
                                            let idx = likedTracks.firstIndex(where: { $0.id == track.id }) ?? 0
                                            AudioPlayerManager.shared.play(queue: likedTracks, startingAt: idx, context: "Liked Songs")
                                        }) {
                                            HStack(spacing: 14) {
                                                let coverUrl = DowntifyAPI.shared.coverUrl(trackId: track.id, size: 100)
                                                AuthenticatedArtworkImage(url: coverUrl, size: 52, cornerRadius: DowntifyShape.coverRadius)

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

                                                Image(systemName: DowntifyIcons.heartFill)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(DowntifyColor.primary)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } header: {
                                    Text(group.letter)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(DowntifyColor.textSecondary)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(DowntifyColor.backgroundDark.opacity(0.95))
                                        .id("header_\(group.letter)")
                                }
                            }
                        }
                    }

                    Spacer(minLength: 100)
                }

                if !likedTracks.isEmpty {
                    AlphaIndexSidebar(proxy: proxy)
                }
            }
        }
        .background(DowntifyColor.backgroundDark.ignoresSafeArea())
        .navigationTitle("Liked Songs")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CustomSubmenuBackButton()
            }
        }
    }
}

// MARK: - SUBMENU: Podcasts (Back Button "<")
public struct LibraryPodcastsSubmenuView: View {
    public init() {}

    public var body: some View {
        PodcastsView()
            .navigationTitle("Podcasts")
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CustomSubmenuBackButton()
                }
            }
    }
}
