import Foundation

/// A subscribed podcast show on the Downtify server.
public struct PodcastShow: Identifiable, Equatable, Hashable {
    public let id: Int64
    public let name: String
    public let author: String
    public let description: String
    public let artworkUrl: String
    public let episodeCount: Int
    public let downloadedCount: Int
    
    public init(
        id: Int64,
        name: String,
        author: String = "",
        description: String = "",
        artworkUrl: String = "",
        episodeCount: Int = 0,
        downloadedCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.description = description
        self.artworkUrl = artworkUrl
        self.episodeCount = episodeCount
        self.downloadedCount = downloadedCount
    }
}

/// An episode of a podcast show with playback position.
public struct PodcastEpisode: Identifiable, Equatable, Hashable {
    public let id: Int64
    public let showId: Int64
    public let title: String
    public let description: String
    public let publishedAt: String
    public let durationSeconds: Int
    public let seasonNumber: Int?
    public let episodeNumber: Int?
    public let filename: String?
    public var positionSeconds: Double
    public var played: Bool
    
    public init(
        id: Int64,
        showId: Int64,
        title: String,
        description: String = "",
        publishedAt: String = "",
        durationSeconds: Int = 0,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        filename: String? = nil,
        positionSeconds: Double = 0.0,
        played: Bool = false
    ) {
        self.id = id
        self.showId = showId
        self.title = title
        self.description = description
        self.publishedAt = publishedAt
        self.durationSeconds = durationSeconds
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.filename = filename
        self.positionSeconds = positionSeconds
        self.played = played
    }
    
    public var isDownloaded: Bool {
        !(filename?.isEmpty ?? true)
    }
    
    public var progressFraction: Double {
        if played { return 1.0 }
        guard durationSeconds > 0 else { return 0.0 }
        return min(max(positionSeconds / Double(durationSeconds), 0.0), 1.0)
    }
    
    public var formattedDuration: String {
        let mins = durationSeconds / 60
        if mins >= 60 {
            let hours = mins / 60
            let remMins = mins % 60
            return "\(hours) hr \(remMins) min"
        } else {
            return "\(mins) min"
        }
    }
}

public struct EpisodeProgress: Codable, Equatable {
    public let positionSeconds: Double
    public let played: Bool
    
    public init(positionSeconds: Double, played: Bool) {
        self.positionSeconds = positionSeconds
        self.played = played
    }
    
    enum CodingKeys: String, CodingKey {
        case positionSeconds = "position_seconds"
        case played
    }
}

/// Tracks episode playback progress and syncs to server every 10 seconds.
@MainActor
public final class EpisodeProgressTracker {
    public static let shared = EpisodeProgressTracker()
    
    private var currentEpisodeId: Int64?
    private var durationSeconds: Int = 0
    private var lastSavedPosition: Double = 0
    
    private init() {}
    
    public func startTracking(episode: PodcastEpisode) {
        self.currentEpisodeId = episode.id
        self.durationSeconds = episode.durationSeconds
        self.lastSavedPosition = episode.positionSeconds
    }
    
    public func tick(positionSeconds: Double) {
        guard let episodeId = currentEpisodeId else { return }
        if abs(positionSeconds - lastSavedPosition) >= 10.0 {
            lastSavedPosition = positionSeconds
            let isNearlyDone = durationSeconds > 0 && positionSeconds >= Double(durationSeconds - 3)
            let progress = EpisodeProgress(positionSeconds: positionSeconds, played: isNearlyDone)
            
            Task {
                try? await DowntifyAPI.shared.updateEpisodePlayback(episodeId: episodeId, progress: progress)
            }
        }
    }
    
    public func stopTracking() {
        self.currentEpisodeId = nil
    }
}

extension Track {
    public init(podcast: PodcastEpisode, show: PodcastShow? = nil) {
        self.init(
            id: "podcast_\(podcast.id)",
            file: podcast.filename ?? "",
            title: podcast.title,
            artist: show?.name ?? show?.author ?? "Podcast",
            artists: [show?.author ?? "Podcast"],
            album: show?.name ?? "Podcasts",
            albumArtist: show?.author ?? "",
            albumId: "",
            artistId: "",
            trackNumber: podcast.episodeNumber ?? 1,
            year: "",
            duration: Double(podcast.durationSeconds),
            codec: "mp3",
            bitrate: 192,
            sampleRate: 44100,
            channels: 2,
            size: 0,
            added: Int64(Date().timeIntervalSince1970),
            hasCover: !(show?.artworkUrl.isEmpty ?? true),
            playlists: []
        )
    }
}
