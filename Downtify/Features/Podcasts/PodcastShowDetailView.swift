import SwiftUI

public struct PodcastShowDetailView: View {
    public let show: PodcastShow
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var player = AudioPlayerManager.shared
    
    @State private var episodes: [PodcastEpisode] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var playbackRate: Float = 1.0
    @State private var isDescriptionExpanded = false
    
    let rates: [Float] = [1.0, 1.25, 1.5, 2.0]
    
    public init(show: PodcastShow) {
        self.show = show
    }
    
    public var body: some View {
        List {
            // Show Header
            VStack(alignment: .center, spacing: 12) {
                AuthenticatedArtworkImage(
                    url: URL(string: show.artworkUrl),
                    size: 180,
                    cornerRadius: DowntifyShape.coverRadius
                )
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
                
                Text(show.name)
                    .font(DowntifyFont.sectionTitle)
                    .foregroundColor(DowntifyColor.textPrimary)
                    .multilineTextAlignment(.center)
                
                if !show.author.isEmpty {
                    Text(show.author)
                        .font(DowntifyFont.body)
                        .foregroundColor(DowntifyColor.textSecondary)
                }
                
                if !show.description.isEmpty {
                    Text(show.description)
                        .font(DowntifyFont.caption)
                        .foregroundColor(DowntifyColor.textTertiary)
                        .lineLimit(isDescriptionExpanded ? nil : 3)
                        .multilineTextAlignment(.center)
                        .onTapGesture {
                            withAnimation {
                                isDescriptionExpanded.toggle()
                            }
                        }
                }
                
                // Playback Speed Selector
                HStack(spacing: 8) {
                    Text("Speed:")
                        .font(DowntifyFont.caption)
                        .foregroundColor(DowntifyColor.textSecondary)
                    
                    ForEach(rates, id: \.self) { rate in
                        Button(action: {
                            playbackRate = rate
                            player.setPlaybackRate(rate)
                        }) {
                            Text(String(format: "%.2gx", rate))
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(playbackRate == rate ? DowntifyColor.primary : DowntifyColor.surfaceRaised)
                                .foregroundColor(playbackRate == rate ? .black : DowntifyColor.textPrimary)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .padding(.vertical, 8)
            
            // Episodes Section Header
            Section {
                if isLoading && episodes.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView().tint(DowntifyColor.primary)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if let error = errorMessage, episodes.isEmpty {
                    VStack(spacing: 8) {
                        Text("Failed to load episodes")
                            .font(DowntifyFont.bodyBold)
                            .foregroundColor(.orange)
                        Text(error)
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                        Button("Retry") {
                            Task { await loadEpisodes() }
                        }
                        .font(DowntifyFont.caption)
                        .foregroundColor(DowntifyColor.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(episodes) { episode in
                        PodcastEpisodeRow(
                            episode: episode,
                            show: show,
                            isPlayingThis: isEpisodePlaying(episode),
                            onPlayTapped: {
                                handlePlayEpisode(episode)
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
            } header: {
                Text("Episodes (\(episodes.count))")
                    .font(DowntifyFont.cardTitle)
                    .foregroundColor(DowntifyColor.textSecondary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.currentBackground.ignoresSafeArea())
        .navigationTitle(show.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadEpisodes()
        }
        .task {
            await loadEpisodes()
        }
    }
    
    private func isEpisodePlaying(_ episode: PodcastEpisode) -> Bool {
        player.currentTrack?.id == "podcast_\(episode.id)" && player.state == .playing
    }
    
    private func handlePlayEpisode(_ episode: PodcastEpisode) {
        let trackId = "podcast_\(episode.id)"
        if player.currentTrack?.id == trackId {
            player.togglePlayPause()
        } else {
            let track = Track(podcast: episode, show: show)
            player.play(track: track, context: show.name)
            EpisodeProgressTracker.shared.startTracking(episode: episode)
            if episode.positionSeconds > 3 && !episode.played {
                player.seek(to: episode.positionSeconds)
            }
        }
    }
    
    private func loadEpisodes() async {
        isLoading = true
        errorMessage = nil
        do {
            self.episodes = try await DowntifyAPI.shared.fetchPodcastEpisodes(showId: show.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Episode Row

struct PodcastEpisodeRow: View {
    let episode: PodcastEpisode
    let show: PodcastShow
    let isPlayingThis: Bool
    let onPlayTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Play Button
                Button(action: onPlayTapped) {
                    ZStack {
                        Circle()
                            .fill(isPlayingThis ? DowntifyColor.primary : DowntifyColor.surfaceRaised)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                            .font(.system(size: 18))
                            .foregroundColor(isPlayingThis ? .black : DowntifyColor.textPrimary)
                    }
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(DowntifyFont.bodyBold)
                        .foregroundColor(DowntifyColor.textPrimary)
                        .lineLimit(2)
                    
                    if !episode.description.isEmpty {
                        Text(episode.description)
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textTertiary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 8) {
                        if !episode.publishedAt.isEmpty {
                            Text(episode.publishedAt)
                                .font(DowntifyFont.caption)
                                .foregroundColor(DowntifyColor.textSecondary)
                        }
                        
                        Text("•")
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                        
                        Text(episode.formattedDuration)
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                        
                        if episode.played {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(DowntifyColor.primary)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Progress Bar if started
            if episode.progressFraction > 0 && !episode.played {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(DowntifyColor.surfaceRaised)
                            .frame(height: 3)
                        Capsule()
                            .fill(DowntifyColor.primary)
                            .frame(width: geo.size.width * episode.progressFraction, height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DowntifyShape.cardRadius, style: .continuous)
                .fill(DowntifyColor.surface)
        )
    }
}
