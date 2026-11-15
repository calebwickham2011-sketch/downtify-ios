import SwiftUI

/// Queue management screen matching Downtify Android's `QueueScreen.kt`.
/// Displays Now Playing, Up Next (with drag-and-drop reordering & swipe-to-delete),
/// and playback History.
public struct UpNextQueueView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isEditing: Bool = false
    @State private var showHistory: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // MARK: - Now Playing
                if let current = player.currentTrack {
                    Section {
                        nowPlayingCard(track: current)
                    } header: {
                        Text("Now Playing")
                            .font(DowntifyFont.caption.bold())
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                    .listRowBackground(DowntifyColor.surfaceRaised)
                }
                
                // MARK: - Up Next
                let upcoming = player.upcoming
                Section {
                    if upcoming.isEmpty {
                        Text("No upcoming tracks. Queue songs from your library, albums, or playlists.")
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(Array(upcoming.enumerated()), id: \.element.id) { offset, track in
                            let absoluteIndex = player.queueIndex + 1 + offset
                            Button {
                                player.play(queue: player.queue, startingAt: absoluteIndex)
                            } label: {
                                queueRow(track: track, index: absoluteIndex, isPlaying: false)
                            }
                            .buttonStyle(.plain)
                        }
                        .onMove { sourceIndices, destination in
                            player.moveUpcoming(fromOffsets: sourceIndices, toOffset: destination)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                player.removeUpcoming(at: index)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Up Next (\(upcoming.count))")
                            .font(DowntifyFont.caption.bold())
                            .foregroundColor(DowntifyColor.textSecondary)
                        
                        Spacer()
                        
                        if !upcoming.isEmpty {
                            Button("Clear") {
                                withAnimation {
                                    player.clearUpcoming()
                                }
                            }
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.primary)
                        }
                    }
                }
                .listRowBackground(DowntifyColor.surface)
                
                // MARK: - History Section
                let history = player.history
                if !history.isEmpty {
                    Section {
                        DisclosureGroup(isExpanded: $showHistory) {
                            ForEach(Array(history.enumerated()), id: \.element.id) { index, track in
                                Button {
                                    player.play(queue: player.queue, startingAt: index)
                                } label: {
                                    queueRow(track: track, index: index, isPlaying: false)
                                        .opacity(0.7)
                                }
                                .buttonStyle(.plain)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(DowntifyColor.textSecondary)
                                Text("Recently Played (\(history.count))")
                                    .font(DowntifyFont.cardTitle)
                                    .foregroundColor(DowntifyColor.textPrimary)
                            }
                        }
                    }
                    .listRowBackground(DowntifyColor.surface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(DowntifyColor.backgroundDark.ignoresSafeArea())
            .navigationTitle("Play Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .foregroundColor(DowntifyColor.primary)
                }
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
    
    // MARK: - Now Playing Card
    private func nowPlayingCard(track: Track) -> some View {
        HStack(spacing: 14) {
            let coverUrl = track.hasCover ? DowntifyAPI.shared.coverUrl(trackId: track.id, size: 100) : nil
            AuthenticatedArtworkImage(url: coverUrl, size: 48, cornerRadius: 8)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(track.displayTitle)
                    .font(DowntifyFont.cardTitle)
                    .foregroundColor(DowntifyColor.primary)
                    .lineLimit(1)
                
                Text(track.displayArtist)
                    .font(DowntifyFont.caption)
                    .foregroundColor(DowntifyColor.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Animated waveform icon
            Image(systemName: "waveform")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(DowntifyColor.primary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Queue Row
    private func queueRow(track: Track, index: Int, isPlaying: Bool) -> some View {
        HStack(spacing: 12) {
            let coverUrl = track.hasCover ? DowntifyAPI.shared.coverUrl(trackId: track.id, size: 80) : nil
            AuthenticatedArtworkImage(url: coverUrl, size: 42, cornerRadius: 6)
            
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
            
            Text(formatDuration(track.duration))
                .font(DowntifyFont.caption.monospacedDigit())
                .foregroundColor(DowntifyColor.textTertiary)
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
