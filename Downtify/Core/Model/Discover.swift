import Foundation

/// An artist recommended from library seeds.
public struct DiscoverArtist: Identifiable, Equatable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let pictureUrl: String
    public let because: [String]
    public let spotifyUrl: String
    
    public init(name: String, pictureUrl: String = "", because: [String] = [], spotifyUrl: String = "") {
        self.name = name
        self.pictureUrl = pictureUrl
        self.because = because
        self.spotifyUrl = spotifyUrl
    }
}

/// An album suggested based on library listening habits.
public struct DiscoverAlbum: Identifiable, Equatable, Hashable, Sendable {
    public var id: String { url.isEmpty ? "\(artist)_\(name)" : url }
    public let name: String
    public let artist: String
    public let year: String
    public let coverUrl: String
    public let url: String
    public let reason: String // "similar" or "more_from"
    public let because: [String]
    
    public init(
        name: String,
        artist: String = "",
        year: String = "",
        coverUrl: String = "",
        url: String = "",
        reason: String = "",
        because: [String] = []
    ) {
        self.name = name
        self.artist = artist
        self.year = year
        self.coverUrl = coverUrl
        self.url = url
        self.reason = reason
        self.because = because
    }
}

/// A playlist suggested around a library or discovered artist.
public struct DiscoverPlaylist: Identifiable, Equatable, Hashable, Sendable {
    public var id: String { url.isEmpty ? name : url }
    public let name: String
    public let owner: String
    public let coverUrl: String
    public let url: String
    public let reason: String // "radio" or "this_is"
    public let artist: String
    
    public init(
        name: String,
        owner: String = "",
        coverUrl: String = "",
        url: String = "",
        reason: String = "",
        artist: String = ""
    ) {
        self.name = name
        self.owner = owner
        self.coverUrl = coverUrl
        self.url = url
        self.reason = reason
        self.artist = artist
    }
}

public struct DiscoverCollections: Equatable, Sendable {
    public let albums: [DiscoverAlbum]
    public let moreAlbums: [DiscoverAlbum]
    public let playlists: [DiscoverPlaylist]
    public let artistUrls: [String: String]
    public let partial: Bool
    
    public init(
        albums: [DiscoverAlbum] = [],
        moreAlbums: [DiscoverAlbum] = [],
        playlists: [DiscoverPlaylist] = [],
        artistUrls: [String: String] = [:],
        partial: Bool = false
    ) {
        self.albums = albums
        self.moreAlbums = moreAlbums
        self.playlists = playlists
        self.artistUrls = artistUrls
        self.partial = partial
    }
}
