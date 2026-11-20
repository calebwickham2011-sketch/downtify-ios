import Foundation

/// Accent- and case-insensitive word matching matching Downtify's `TextSearch.kt`.
public enum TextSearch {
    public static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns true if every word in `query` appears in at least one of the `fields`.
    public static func matches(query: String, fields: [String]) -> Bool {
        let normalizedQuery = normalize(query)
        let words = normalizedQuery.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        if words.isEmpty { return false }
        
        let haystack = fields.map { normalize($0) }.joined(separator: " ")
        return words.allSatisfy { haystack.contains($0) }
    }
}

/// A song found on the remote server catalog (e.g. YouTube Music / Deezer).
public struct RemoteSong: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let artists: [String]
    public let album: String
    public let coverUrl: String
    public let durationSeconds: Int
    public let url: String
    
    public var artist: String {
        artists.joined(separator: ", ")
    }
    
    public init(
        id: String,
        title: String,
        artists: [String] = [],
        album: String = "",
        coverUrl: String = "",
        durationSeconds: Int = 0,
        url: String = ""
    ) {
        self.id = id
        self.title = title
        self.artists = artists
        self.album = album
        self.coverUrl = coverUrl
        self.durationSeconds = durationSeconds
        self.url = url
    }
}

/// An album found on the remote server catalog.
public struct RemoteAlbum: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let coverUrl: String
    public let year: String
    public let url: String
    
    public init(
        id: String,
        title: String,
        artist: String = "",
        coverUrl: String = "",
        year: String = "",
        url: String = ""
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.coverUrl = coverUrl
        self.year = year
        self.url = url
    }
}

/// Aggregated search results from remote server catalog.
public struct CatalogSearchResult: Equatable {
    public let songs: [RemoteSong]
    public let albums: [RemoteAlbum]
    
    public init(songs: [RemoteSong] = [], albums: [RemoteAlbum] = []) {
        self.songs = songs
        self.albums = albums
    }
    
    public var isEmpty: Bool {
        songs.isEmpty && albums.isEmpty
    }
}

extension Track {
    public init(remote: RemoteSong) {
        self.init(
            id: remote.id,
            file: remote.url,
            title: remote.title,
            artist: remote.artist,
            artists: remote.artists,
            album: remote.album,
            albumArtist: remote.artist,
            albumId: "",
            artistId: "",
            trackNumber: 1,
            year: "",
            duration: Double(remote.durationSeconds),
            codec: "mp3",
            bitrate: 320,
            sampleRate: 44100,
            channels: 2,
            size: 0,
            added: Int64(Date().timeIntervalSince1970),
            hasCover: !remote.coverUrl.isEmpty,
            playlists: []
        )
    }
}
