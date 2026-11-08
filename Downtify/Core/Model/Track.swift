import Foundation

public struct Track: Codable, Identifiable, Equatable, Hashable {
    public let id: String
    public let file: String
    public let title: String
    public let artist: String
    public let artists: [String]
    public let album: String
    public let albumArtist: String
    public let albumId: String
    public let artistId: String
    public let trackNumber: Int
    public let year: String
    public let duration: Double
    public let codec: String
    public let bitrate: Int
    public let sampleRate: Int
    public let channels: Int
    public let size: Int64
    public let added: Int64
    public let hasCover: Bool
    public let playlists: [String]
    
    public var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let fileName = (file as NSString).lastPathComponent
        return (fileName as NSString).deletingPathExtension
    }
    
    public var displayArtist: String {
        let a = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return a.isEmpty ? albumArtist : a
    }
    
    public var isLossless: Bool {
        let c = codec.lowercased()
        return c == "flac" || c == "alac" || c == "wav"
    }
    
    enum CodingKeys: String, CodingKey {
        case id, file, title, artist, artists, album
        case albumArtist = "album_artist"
        case albumId = "album_id"
        case artistId = "artist_id"
        case trackNumber = "track_number"
        case year, duration, codec, bitrate
        case sampleRate = "sample_rate"
        case channels, size, added
        case hasCover = "has_cover"
        case playlists
    }
}
