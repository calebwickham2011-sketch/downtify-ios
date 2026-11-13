import SwiftUI

/// Displays all tracks in an album and starts playback when one is tapped.
struct AlbumDetailView: View {
    let album: Album
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var library = LibraryService.shared

    var tracks: [Track] {
        library.tracks.filter { $0.albumId == album.id }
            .sorted { $0.trackNumber < $1.trackNumber }
    }

    var body: some View {
        List {
            // Album header
            VStack(alignment: .center, spacing: 10) {
                let coverUrl = album.coverTrackId.flatMap { DowntifyAPI.shared.coverUrl(trackId: $0, size: 400) }
                AuthenticatedArtworkImage(url: coverUrl, size: 200, cornerRadius: DowntifyShape.coverRadius)
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

                // Shuffle / Play all buttons
                HStack(spacing: 16) {
                    Button {
                        AudioPlayerManager.shared.play(queue: tracks.shuffled(), startingAt: 0)
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .font(DowntifyFont.cardTitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DowntifyColor.surfaceRaised)
                            .cornerRadius(10)
                    }
                    Button {
                        AudioPlayerManager.shared.play(queue: tracks, startingAt: 0)
                    } label: {
                        Label("Play All", systemImage: "play.fill")
                            .font(DowntifyFont.cardTitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DowntifyColor.primary)
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
                    AudioPlayerManager.shared.play(queue: tracks, startingAt: idx)
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
                            if track.displayArtist != album.artist {
                                Text(track.displayArtist)
                                    .font(DowntifyFont.caption)
                                    .foregroundColor(DowntifyColor.textSecondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Text(formatDuration(track.duration))
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .background(DowntifyColor.backgroundDark.ignoresSafeArea())
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
