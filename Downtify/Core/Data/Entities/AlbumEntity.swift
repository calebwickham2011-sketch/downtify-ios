import Foundation
import SwiftData

/// SwiftData persistent model for a music album.
/// Albums are assembled from track metadata, so this entity stores
/// the denormalized album-level fields cached from the track list.
@Model
public final class AlbumEntity {
    @Attribute(.unique) public var id: String
    public var title: String
    public var artist: String
    public var artistId: String
    public var year: String
    public var added: Int64
    /// Serialised track IDs in order (looked up from TrackEntity at read time).
    public var trackIds: [String]

    public init(
        id: String,
        title: String = "",
        artist: String = "",
        artistId: String = "",
        year: String = "",
        added: Int64 = 0,
        trackIds: [String] = []
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artistId = artistId
        self.year = year
        self.added = added
        self.trackIds = trackIds
    }

    public convenience init(from album: Album) {
        self.init(
            id: album.id,
            title: album.title,
            artist: album.artist,
            artistId: album.artistId,
            year: album.year,
            added: album.added,
            trackIds: album.tracks.map(\.id)
        )
    }
}
