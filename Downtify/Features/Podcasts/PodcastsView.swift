import SwiftUI

public struct PodcastsView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var shows: [PodcastShow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading && shows.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(DowntifyColor.primary)
                            .scaleEffect(1.3)
                        Text("Loading subscribed podcasts...")
                            .font(DowntifyFont.body)
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else if let error = errorMessage, shows.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 36))
                            .foregroundColor(.orange)
                        Text("Couldn't load podcasts")
                            .font(DowntifyFont.sectionTitle)
                            .foregroundColor(DowntifyColor.textPrimary)
                        Text(error)
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("Retry") {
                            Task { await loadShows() }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(DowntifyColor.primary)
                        .foregroundColor(.black)
                        .cornerRadius(20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else if shows.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 44))
                            .foregroundColor(DowntifyColor.textSecondary)
                        Text("No Podcasts Subscribed")
                            .font(DowntifyFont.sectionTitle)
                            .foregroundColor(DowntifyColor.textPrimary)
                        Text("Subscribe to shows on your Downtify server to stream or download episodes.")
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                        spacing: 16
                    ) {
                        ForEach(shows) { show in
                            NavigationLink(destination: PodcastShowDetailView(show: show)) {
                                PodcastShowCard(show: show)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                
                Spacer(minLength: 80)
            }
        }
        .background(theme.currentBackground.ignoresSafeArea())
        .navigationTitle("Podcasts")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await loadShows()
        }
        .task {
            if shows.isEmpty {
                await loadShows()
            }
        }
    }
    
    private func loadShows() async {
        isLoading = true
        errorMessage = nil
        do {
            self.shows = try await DowntifyAPI.shared.fetchPodcastShows()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct PodcastShowCard: View {
    let show: PodcastShow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AuthenticatedArtworkImage(
                url: URL(string: show.artworkUrl),
                size: 160,
                cornerRadius: DowntifyShape.coverRadius
            )
            .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
            
            Text(show.name)
                .font(DowntifyFont.cardTitle)
                .foregroundColor(DowntifyColor.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if !show.author.isEmpty {
                Text(show.author)
                    .font(DowntifyFont.caption)
                    .foregroundColor(DowntifyColor.textSecondary)
                    .lineLimit(1)
            }
            
            HStack(spacing: 6) {
                Text("\(show.episodeCount) eps")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DowntifyColor.textTertiary)
                
                if show.downloadedCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                        Text("\(show.downloadedCount)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(DowntifyColor.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
