import Foundation

/// Accent- and case-insensitive word matching matching Downtify's `TextSearch.kt`.
public enum TextSearch: Sendable {
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

/// Helper for detecting and extracting YouTube video IDs for server stream caching.
public enum StreamVideo: Sendable {
    private static let videoIdRegex = try? NSRegularExpression(pattern: "^[A-Za-z0-9_-]{11}$")

    public static func isVideoId(_ text: String) -> Bool {
        guard let regex = videoIdRegex else { return text.count == 11 }
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    /// The video id to stream without asking the server: the song's own id or the 'v' query param of a watch URL.
    public static func videoId(of song: RemoteSong) -> String? {
        if isVideoId(song.id) { return song.id }
        if song.url.contains("watch") {
            guard let components = URLComponents(string: song.url),
                  let queryItems = components.queryItems,
                  let v = queryItems.first(where: { $0.name == "v" })?.value,
                  isVideoId(v) else { return nil }
            return v
        }
        return nil
    }
}

/// A song found on the remote server catalog (e.g. YouTube Music / Deezer / Spotify).
public struct RemoteSong: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let artists: [String]
    public let album: String
    public let coverUrl: String
    public let durationSeconds: Int
    public let url: String
    public let source: String
    public let previewUrl: String
    public let year: String
    public let rawJson: String?
    
    public var artist: String {
        artists.joined(separator: ", ")
    }
    
    public var rawDictionary: [String: Any]? {
        guard let rawJson = rawJson, let data = rawJson.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
    
    public init(
        id: String,
        title: String,
        artists: [String] = [],
        album: String = "",
        coverUrl: String = "",
        durationSeconds: Int = 0,
        url: String = "",
        source: String = "",
        previewUrl: String = "",
        year: String = "",
        rawJson: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artists = artists
        self.album = album
        self.coverUrl = coverUrl
        self.durationSeconds = durationSeconds
        self.url = url
        self.source = source
        self.previewUrl = previewUrl
        self.year = year
        self.rawJson = rawJson
    }
}

/// An album found on the remote server catalog.
public struct RemoteAlbum: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let coverUrl: String
    public let year: String
    public let url: String
    public let releaseType: String
    
    public init(
        id: String,
        title: String,
        artist: String = "",
        coverUrl: String = "",
        year: String = "",
        url: String = "",
        releaseType: String = ""
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.coverUrl = coverUrl
        self.year = year
        self.url = url
        self.releaseType = releaseType
    }
}

/// What a resolved album / playlist / track link points at (`GET /api/url/resolve`).
public struct ResolvedLink: Codable, Equatable, Sendable {
    public let url: String
    public let kind: String
    public let name: String
    public let subtitle: String
    public let coverUrl: String
    public let year: String
    public let tracks: [RemoteSong]
    public let albums: [RemoteAlbum]
    
    public init(
        url: String,
        kind: String = "album",
        name: String = "",
        subtitle: String = "",
        coverUrl: String = "",
        year: String = "",
        tracks: [RemoteSong] = [],
        albums: [RemoteAlbum] = []
    ) {
        self.url = url
        self.kind = kind
        self.name = name
        self.subtitle = subtitle
        self.coverUrl = coverUrl
        self.year = year
        self.tracks = tracks
        self.albums = albums
    }
}

/// Aggregated search results from remote server catalog.
public struct CatalogSearchResult: Equatable, Sendable {
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
    public init(remote: RemoteSong, streamVideoId: String? = nil) {
        let vid = streamVideoId ?? StreamVideo.videoId(of: remote) ?? remote.id
        self.init(
            id: "stream:\(vid)",
            file: remote.url,
            title: remote.title,
            artist: remote.artist,
            artists: remote.artists,
            album: remote.album,
            albumArtist: remote.artist,
            albumId: "",
            artistId: "",
            trackNumber: 1,
            year: remote.year,
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
