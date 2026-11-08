import Foundation

public struct Album: Identifiable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let artistId: String
    public let year: String
    public let tracks: [Track]
    public let added: Int64
    
    public var trackCount: Int { tracks.count }
    public var duration: Double { tracks.reduce(0.0) { $0 + $1.duration } }
    public var coverTrackId: String? { tracks.first(where: { $0.hasCover })?.id }
}

public struct Artist: Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let albums: [Album]
    public let tracks: [Track]
    
    public var coverTrackId: String? {
        albums.compactMap { $0.coverTrackId }.first ?? tracks.first(where: { $0.hasCover })?.id
    }
}

public struct Playlist: Identifiable, Equatable, Hashable {
    public var id: String { name }
    public let name: String
    public let liked: Bool
    public let cover: String
    public let trackIds: [String]
    public let favorite: Bool
    public let displayName: String
    public let favoriteSupported: Bool
    
    public var title: String {
        displayName.isEmpty ? name : displayName
    }
}
