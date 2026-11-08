import Foundation
import SwiftData

@Model
public final class TrackEntity {
    @Attribute(.unique) public var id: String
    public var file: String
    public var title: String
    public var artist: String
    public var artists: [String]
    public var album: String
    public var albumArtist: String
    public var albumId: String
    public var artistId: String
    public var trackNumber: Int
    public var year: String
    public var duration: Double
    public var codec: String
    public var bitrate: Int
    public var sampleRate: Int
    public var channels: Int
    public var size: Int64
    public var added: Int64
    public var hasCover: Bool
    public var playlists: [String]
    public var isLiked: Bool
    
    public init(
        id: String,
        file: String = "",
        title: String = "",
        artist: String = "",
        artists: [String] = [],
        album: String = "",
        albumArtist: String = "",
        albumId: String = "",
        artistId: String = "",
        trackNumber: Int = 0,
        year: String = "",
        duration: Double = 0.0,
        codec: String = "",
        bitrate: Int = 0,
        sampleRate: Int = 0,
        channels: Int = 0,
        size: Int64 = 0,
        added: Int64 = 0,
        hasCover: Bool = false,
        playlists: [String] = [],
        isLiked: Bool = false
    ) {
        self.id = id
        self.file = file
        self.title = title
        self.artist = artist
        self.artists = artists
        self.album = album
        self.albumArtist = albumArtist
        self.albumId = albumId
        self.artistId = artistId
        self.trackNumber = trackNumber
        self.year = year
        self.duration = duration
        self.codec = codec
        self.bitrate = bitrate
        self.sampleRate = sampleRate
        self.channels = channels
        self.size = size
        self.added = added
        self.hasCover = hasCover
        self.playlists = playlists
        self.isLiked = isLiked
    }
    
    public convenience init(from track: Track, isLiked: Bool = false) {
        self.init(
            id: track.id,
            file: track.file,
            title: track.title,
            artist: track.artist,
            artists: track.artists,
            album: track.album,
            albumArtist: track.albumArtist,
            albumId: track.albumId,
            artistId: track.artistId,
            trackNumber: track.trackNumber,
            year: track.year,
            duration: track.duration,
            codec: track.codec,
            bitrate: track.bitrate,
            sampleRate: track.sampleRate,
            channels: track.channels,
            size: track.size,
            added: track.added,
            hasCover: track.hasCover,
            playlists: track.playlists,
            isLiked: isLiked
        )
    }
    
    public func toModel() -> Track {
        Track(
            id: id,
            file: file,
            title: title,
            artist: artist,
            artists: artists,
            album: album,
            albumArtist: albumArtist,
            albumId: albumId,
            artistId: artistId,
            trackNumber: trackNumber,
            year: year,
            duration: duration,
            codec: codec,
            bitrate: bitrate,
            sampleRate: sampleRate,
            channels: channels,
            size: size,
            added: added,
            hasCover: hasCover,
            playlists: playlists
        )
    }
}
