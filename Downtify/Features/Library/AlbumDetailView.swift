import SwiftUI

/// Displays all tracks in an album, starts playback, and manages offline downloads.
public struct AlbumDetailView: View {
    public let album: Album
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var library = LibraryService.shared
    @ObservedObject private var downloadManager = OfflineDownloadManager.shared

    @State private var showDownloadConfirm = false
    @State private var showRemoveConfirm = false

    public init(album: Album) {
        self.album = album
    }

    private var tracks: [Track] {
        library.tracks.filter { $0.albumId == album.id }
            .sorted { $0.trackNumber < $1.trackNumber }
    }
    
    private var isAlbumFullyDownloaded: Bool {
        !tracks.isEmpty && tracks.allSatisfy { downloadManager.isDownloaded(trackId: $0.id) }
    }
    
    private var isAlbumDownloading: Bool {
        tracks.contains { downloadManager.isDownloading(trackId: $0.id) }
    }
    
    private var downloadedTrackCount: Int {
        tracks.filter { downloadManager.isDownloaded(trackId: $0.id) }.count
    }

    public var body: some View {
        List {
            // Album header
            VStack(alignment: .center, spacing: 10) {
                let coverUrl = album.coverTrackId.flatMap { DowntifyAPI.shared.coverUrl(trackId: $0, size: 400) }
                AuthenticatedArtworkImage(url: coverUrl, size: 200, cornerRadius: DowntifyShape.coverRadius)
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                
                Text(album.title)
                    .font(DowntifyFont.sectionTitle)
                    .foregroundColor(DowntifyColor.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(album.artist)
                    .font(DowntifyFont.body)
                    .foregroundColor(DowntifyColor.textSecondary)
                
                if !album.year.isEmpty {
                    Text(album.year)
                        .font(DowntifyFont.caption)
                        .foregroundColor(DowntifyColor.textTertiary)
                }

                // Action buttons: Shuffle, Play All, Download
                HStack(spacing: 12) {
                    Button {
                        AudioPlayerManager.shared.play(queue: tracks.shuffled(), startingAt: 0, context: "Playing from album")
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .font(DowntifyFont.cardTitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DowntifyColor.surfaceRaised)
                            .cornerRadius(10)
                    }
                    
                    Button {
                        AudioPlayerManager.shared.play(queue: tracks, startingAt: 0, context: "Playing from album")
                    } label: {
                        Label("Play All", systemImage: "play.fill")
                            .font(DowntifyFont.cardTitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DowntifyColor.primary)
                            .cornerRadius(10)
                    }
                    
                    // Download Album Toggle Button
                    Button {
                        if isAlbumFullyDownloaded {
                            showRemoveConfirm = true
                        } else {
                            showDownloadConfirm = true
                        }
                    } label: {
                        Group {
                            if isAlbumDownloading {
                                ProgressView()
                                    .tint(DowntifyColor.primary)
                                    .frame(width: 44, height: 44)
                            } else if isAlbumFullyDownloaded {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(DowntifyColor.primary)
                                    .frame(width: 44, height: 44)
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(DowntifyColor.textSecondary)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .background(DowntifyColor.surfaceRaised)
                        .cornerRadius(10)
                    }
                }
                .padding(.top, 4)
            }
            .listRowBackground(Color.clear)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)

            // Track rows
            ForEach(Array(tracks.enumerated()), id: \.element.id) { idx, track in
                Button {
                    AudioPlayerManager.shared.play(queue: tracks, startingAt: idx, context: "Playing from album")
                } label: {
                    HStack(spacing: 14) {
                        // Track number / playing indicator
                        if player.currentTrack?.id == track.id && player.state == .playing {
                            Image(systemName: "waveform")
                                .font(.system(size: 16))
                                .foregroundColor(DowntifyColor.primary)
                                .frame(width: 24)
                        } else {
                            Text("\(track.trackNumber > 0 ? track.trackNumber : idx + 1)")
                                .font(DowntifyFont.caption)
                                .foregroundColor(DowntifyColor.textTertiary)
                                .frame(width: 24, alignment: .center)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.displayTitle)
                                .font(DowntifyFont.cardTitle)
                                .foregroundColor(
                                    player.currentTrack?.id == track.id
                                        ? DowntifyColor.primary
                                        : DowntifyColor.textPrimary
                                )
                                .lineLimit(1)
                            
                            HStack(spacing: 6) {
                                // Offline downloaded / downloading badge
                                if downloadManager.isDownloaded(trackId: track.id) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(DowntifyColor.primary)
                                } else if downloadManager.isDownloading(trackId: track.id) {
                                    let prog = downloadManager.progress(for: track.id)
                                    HStack(spacing: 3) {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                        Text("\(Int(prog * 100))%")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(DowntifyColor.primary)
                                    }
                                }
                                
                                if track.displayArtist != album.artist {
                                    Text(track.displayArtist)
                                        .font(DowntifyFont.caption)
                                        .foregroundColor(DowntifyColor.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                        }

                        Spacer()

                        Text(formatDuration(track.duration))
                            .font(DowntifyFont.caption.monospacedDigit())
                            .foregroundColor(DowntifyColor.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing) {
                    if downloadManager.isDownloaded(trackId: track.id) {
                        Button(role: .destructive) {
                            downloadManager.removeDownload(trackId: track.id)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    } else {
                        Button {
                            downloadManager.downloadTrack(track: track)
                        } label: {
                            Label("Download", systemImage: "arrow.down")
                        }
                        .tint(DowntifyColor.primary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(DowntifyColor.backgroundDark.ignoresSafeArea())
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Download Album",
            isPresented: $showDownloadConfirm,
            titleVisibility: .visible
        ) {
            Button("Download \(tracks.count) Songs") {
                downloadManager.downloadAlbum(album: album)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Download '\(album.title)' for offline playback when no connection is available?")
        }
        .confirmationDialog(
            "Remove Downloads",
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove Downloads from Device", role: .destructive) {
                downloadManager.removeAlbumDownloads(album: album)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove \(downloadedTrackCount) downloaded tracks from this album? You can download them again anytime.")
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
