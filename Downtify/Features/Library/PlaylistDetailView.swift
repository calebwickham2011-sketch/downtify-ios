import SwiftUI

/// Displays tracks for a playlist with offline download capabilities and playback controls.
public struct PlaylistDetailView: View {
    public let playlist: Playlist
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var library = LibraryService.shared
    @ObservedObject private var downloadManager = OfflineDownloadManager.shared

    @State private var showDownloadConfirm = false
    @State private var showRemoveConfirm = false

    public init(playlist: Playlist) {
        self.playlist = playlist
    }

    private var tracks: [Track] {
        let set = Set(playlist.trackIds)
        // Maintain the playlist track order
        var ordered: [Track] = []
        let trackMap = Dictionary(uniqueKeysWithValues: library.tracks.map { ($0.id, $0) })
        for id in playlist.trackIds {
            if let track = trackMap[id] {
                ordered.append(track)
            }
        }
        return ordered.isEmpty ? library.tracks.filter { set.contains($0.id) } : ordered
    }
    
    private var isPlaylistFullyDownloaded: Bool {
        !tracks.isEmpty && tracks.allSatisfy { downloadManager.isDownloaded(trackId: $0.id) }
    }
    
    private var isPlaylistDownloading: Bool {
        tracks.contains { downloadManager.isDownloading(trackId: $0.id) }
    }
    
    private var downloadedTrackCount: Int {
        tracks.filter { downloadManager.isDownloaded(trackId: $0.id) }.count
    }

    public var body: some View {
        List {
            // Playlist Header
            VStack(alignment: .center, spacing: 10) {
                let coverUrl = DowntifyAPI.shared.playlistCoverUrl(path: playlist.cover)
                AuthenticatedArtworkImage(url: coverUrl, size: 200, cornerRadius: DowntifyShape.coverRadius)
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                
                Text(playlist.title)
                    .font(DowntifyFont.sectionTitle)
                    .foregroundColor(DowntifyColor.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Playlist • \(tracks.count) tracks")
                    .font(DowntifyFont.body)
                    .foregroundColor(DowntifyColor.textSecondary)

                // Actions: Shuffle, Play All, Download
                HStack(spacing: 12) {
                    Button {
                        AudioPlayerManager.shared.play(queue: tracks.shuffled(), startingAt: 0, context: "Playing from playlist")
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .font(DowntifyFont.cardTitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DowntifyColor.surfaceRaised)
                            .cornerRadius(10)
                    }
                    
                    Button {
                        AudioPlayerManager.shared.play(queue: tracks, startingAt: 0, context: "Playing from playlist")
                    } label: {
                        Label("Play All", systemImage: "play.fill")
                            .font(DowntifyFont.cardTitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DowntifyColor.primary)
                            .cornerRadius(10)
                    }
                    
                    // Download Playlist Toggle Button
                    Button {
                        if isPlaylistFullyDownloaded {
                            showRemoveConfirm = true
                        } else {
                            showDownloadConfirm = true
                        }
                    } label: {
                        Group {
                            if isPlaylistDownloading {
                                ProgressView()
                                    .tint(DowntifyColor.primary)
                                    .frame(width: 44, height: 44)
                            } else if isPlaylistFullyDownloaded {
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

            // Tracks
            ForEach(Array(tracks.enumerated()), id: \.element.id) { idx, track in
                Button {
                    AudioPlayerManager.shared.play(queue: tracks, startingAt: idx, context: "Playing from playlist")
                } label: {
                    HStack(spacing: 14) {
                        if player.currentTrack?.id == track.id && player.state == .playing {
                            Image(systemName: "waveform")
                                .font(.system(size: 16))
                                .foregroundColor(DowntifyColor.primary)
                                .frame(width: 24)
                        } else {
                            Text("\(idx + 1)")
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
                                
                                Text(track.displayArtist)
                                    .font(DowntifyFont.caption)
                                    .foregroundColor(DowntifyColor.textSecondary)
                                    .lineLimit(1)
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
        .navigationTitle(playlist.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Download Playlist",
            isPresented: $showDownloadConfirm,
            titleVisibility: .visible
        ) {
            Button("Download \(tracks.count) Songs") {
                downloadManager.downloadPlaylist(tracks: tracks)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Download '\(playlist.title)' for offline playback?")
        }
        .confirmationDialog(
            "Remove Downloads",
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove Downloads from Device", role: .destructive) {
                downloadManager.removePlaylistDownloads(tracks: tracks)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove \(downloadedTrackCount) downloaded tracks from this playlist?")
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
