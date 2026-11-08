import Foundation
import SwiftData

@Model
public final class PlaylistEntity {
    @Attribute(.unique) public var name: String
    public var liked: Bool
    public var cover: String
    public var position: Int
    public var trackIds: [String]
    public var favorite: Bool
    public var displayName: String
    public var favoriteSupported: Bool
    
    public init(
        name: String,
        liked: Bool = false,
        cover: String = "",
        position: Int = 0,
        trackIds: [String] = [],
        favorite: Bool = false,
        displayName: String = "",
        favoriteSupported: Bool = false
    ) {
        self.name = name
        self.liked = liked
        self.cover = cover
        self.position = position
        self.trackIds = trackIds
        self.favorite = favorite
        self.displayName = displayName
        self.favoriteSupported = favoriteSupported
    }
    
    public convenience init(from playlist: Playlist, position: Int = 0) {
        self.init(
            name: playlist.name,
            liked: playlist.liked,
            cover: playlist.cover,
            position: position,
            trackIds: playlist.trackIds,
            favorite: playlist.favorite,
            displayName: playlist.displayName,
            favoriteSupported: playlist.favoriteSupported
        )
    }
    
    public func toModel() -> Playlist {
        Playlist(
            name: name,
            liked: liked,
            cover: cover,
            trackIds: trackIds,
            favorite: favorite,
            displayName: displayName,
            favoriteSupported: favoriteSupported
        )
    }
}
