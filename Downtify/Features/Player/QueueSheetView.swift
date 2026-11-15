import SwiftUI

/// Sheet displaying the active playback queue and upcoming tracks.
public struct QueueSheetView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // Currently Playing section
                if let current = player.currentTrack {
                    Section("Now Playing") {
                        queueRow(track: current, isPlaying: true, index: player.queueIndex)
                    }
                    .listRowBackground(DowntifyColor.surfaceRaised)
                }
                
                // Upcoming Tracks section
                let upcoming = player.queue.indices.contains(player.queueIndex + 1)
                    ? Array(player.queue[(player.queueIndex + 1)...])
                    : []
                
                Section("Next in Queue (\(upcoming.count))") {
                    if upcoming.isEmpty {
                        Text("Queue is empty. Select an album or playlist to queue tracks.")
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                    } else {
                        ForEach(Array(upcoming.enumerated()), id: \.element.id) { offset, track in
                            let actualIndex = player.queueIndex + 1 + offset
                            Button {
                                player.play(queue: player.queue, startingAt: actualIndex)
                            } label: {
                                queueRow(track: track, isPlaying: false, index: actualIndex)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowBackground(DowntifyColor.surface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(DowntifyColor.backgroundDark.ignoresSafeArea())
            .navigationTitle("Play Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DowntifyColor.primary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func queueRow(track: Track, isPlaying: Bool, index: Int) -> some View {
        HStack(spacing: 12) {
            let coverUrl = track.hasCover ? DowntifyAPI.shared.coverUrl(trackId: track.id, size: 80) : nil
            AuthenticatedArtworkImage(url: coverUrl, size: 40, cornerRadius: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.displayTitle)
                    .font(DowntifyFont.cardTitle)
                    .foregroundColor(isPlaying ? DowntifyColor.primary : DowntifyColor.textPrimary)
                    .lineLimit(1)
                
                Text(track.displayArtist)
                    .font(DowntifyFont.caption)
                    .foregroundColor(DowntifyColor.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isPlaying {
                Image(systemName: "waveform")
                    .font(.system(size: 14))
                    .foregroundColor(DowntifyColor.primary)
            } else {
                Text(formatDuration(track.duration))
                    .font(DowntifyFont.caption.monospacedDigit())
                    .foregroundColor(DowntifyColor.textTertiary)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
