import Foundation
import SwiftData

/// SwiftData persistent model for an artist.
/// Artists are assembled from track/album groupings, so this entity stores
/// the denormalized artist-level metadata cached from those lists.
@Model
public final class ArtistEntity {
    @Attribute(.unique) public var id: String
    public var name: String
    /// Album IDs this artist appears on.
    public var albumIds: [String]
    /// Track IDs this artist appears on.
    public var trackIds: [String]

    public init(
        id: String,
        name: String = "",
        albumIds: [String] = [],
        trackIds: [String] = []
    ) {
        self.id = id
        self.name = name
        self.albumIds = albumIds
        self.trackIds = trackIds
    }

    public convenience init(from artist: Artist) {
        self.init(
            id: artist.id,
            name: artist.name,
            albumIds: artist.albums.map(\.id),
            trackIds: artist.tracks.map(\.id)
        )
    }
}
