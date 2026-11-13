import SwiftUI

public struct LibraryView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var library = LibraryService.shared
    @State private var selectedFilter = "All"
    let filters = ["All", "Playlists", "Albums", "Artists"]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Pills
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
                    .padding(.vertical, 10)
                }
                
                // Library List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Liked Songs row (shown when All or Playlists selected)
                        if selectedFilter == "All" || selectedFilter == "Playlists" {
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
                            .padding(.vertical, 4)
                        }
                        
                        // Playlists
                        if selectedFilter == "All" || selectedFilter == "Playlists" {
                            ForEach(library.playlists) { playlist in
                                HStack(spacing: 14) {
                                    let coverUrl = DowntifyAPI.shared.playlistCoverUrl(path: playlist.cover)
                                    AuthenticatedArtworkImage(
                                        url: coverUrl,
                                        size: 56,
                                        cornerRadius: DowntifyShape.coverRadius
                                    )
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(playlist.title)
                                            .font(DowntifyFont.cardTitle)
                                            .foregroundColor(DowntifyColor.textPrimary)
                                        
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
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // Albums
                        if selectedFilter == "All" || selectedFilter == "Albums" {
                            ForEach(library.albums) { album in
                                NavigationLink(destination: AlbumDetailView(album: album)) {
                                    HStack(spacing: 14) {
                                        let coverUrl = album.coverTrackId.flatMap { DowntifyAPI.shared.coverUrl(trackId: $0, size: 150) }
                                        AuthenticatedArtworkImage(
                                            url: coverUrl,
                                            size: 56,
                                            cornerRadius: DowntifyShape.coverRadius
                                        )
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(album.title)
                                                .font(DowntifyFont.cardTitle)
                                                .foregroundColor(DowntifyColor.textPrimary)
                                            
                                            Text("Album • \(album.artist) • \(album.trackCount) tracks")
                                                .font(DowntifyFont.cardSubtitle)
                                                .foregroundColor(DowntifyColor.textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(DowntifyColor.textTertiary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Artists
                        if selectedFilter == "All" || selectedFilter == "Artists" {
                            ForEach(library.artists) { artist in
                                HStack(spacing: 14) {
                                    let coverUrl = artist.coverTrackId.flatMap { DowntifyAPI.shared.coverUrl(trackId: $0, size: 150) }
                                    AuthenticatedArtworkImage(
                                        url: coverUrl,
                                        size: 56,
                                        cornerRadius: 28 // Round avatar
                                    )
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(artist.name)
                                            .font(DowntifyFont.cardTitle)
                                            .foregroundColor(DowntifyColor.textPrimary)
                                        
                                        Text("Artist • \(artist.albums.count) albums • \(artist.tracks.count) tracks")
                                            .font(DowntifyFont.cardSubtitle)
                                            .foregroundColor(DowntifyColor.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(DowntifyColor.textTertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    Spacer(minLength: 80)
                }
            }
            .background(theme.currentBackground.ignoresSafeArea())
            .navigationTitle("Your Library")
            .refreshable {
                await library.refreshLibrary()
            }
        }
    }
}
