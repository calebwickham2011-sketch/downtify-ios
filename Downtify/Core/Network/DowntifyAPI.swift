import Foundation

public enum APIError: Error, LocalizedError {
    case unauthorized
    case invalidURL
    case noSession
    case invalidResponse(Int)
    case decodingError(Error)
    case serverError(String)
    
    public var errorDescription: String? {
        switch self {
        case .unauthorized: return "Session expired or unauthorized (401)"
        case .invalidURL: return "Invalid API URL"
        case .noSession: return "No active Downtify server session"
        case .invalidResponse(let code): return "Server returned status \(code)"
        case .decodingError(let err): return "Failed to decode response: \(err.localizedDescription)"
        case .serverError(let msg): return msg
        }
    }
}

@MainActor
public class DowntifyAPI {
    public static let shared = DowntifyAPI()
    
    private let sessionStore = KeychainSessionStore.shared
    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    // MARK: - Request Builder with Auth Interceptor
    private func makeRequest(endpoint: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let session = sessionStore.session else {
            throw APIError.noSession
        }
        let cleanBase = session.baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanEndpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanBase)/\(cleanEndpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }
    
    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(0)
        }
        
        // Auto-logout interceptor on 401
        if http.statusCode == 401 {
            if let token = sessionStore.session?.token {
                await MainActor.run {
                    self.sessionStore.onRevoked(token: token)
                }
            }
            throw APIError.unauthorized
        }
        
        guard (200...299).contains(http.statusCode) else {
            throw APIError.invalidResponse(http.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    // MARK: - Endpoints
    
    public func fetchServerInfo() async throws -> ServerInfo {
        let req = try makeRequest(endpoint: "api/server/info")
        return try await execute(req)
    }
    
    // Wire shape for Library response
    private struct LibraryPageResponse: Codable {
        let cursor: Int64?
        let full: Bool?
        let tracks: [Track]?
        let deleted: [String]?
    }
    
    public func fetchLibrary(since: Int64 = 0) async throws -> (cursor: Int64, full: Bool, tracks: [Track], deleted: [String]) {
        let req = try makeRequest(endpoint: "api/v1/library?since=\(since)")
        let page: LibraryPageResponse = try await execute(req)
        return (
            cursor: page.cursor ?? 0,
            full: page.full ?? false,
            tracks: page.tracks ?? [],
            deleted: page.deleted ?? []
        )
    }
    
    // Wire shape for Playlist DTO
    private struct PlaylistDto: Codable {
        let name: String
        let liked: Bool?
        let cover: String?
        let trackIds: [String]?
        let favorite: Bool?
        let displayName: String?
        
        enum CodingKeys: String, CodingKey {
            case name, liked, cover
            case trackIds = "track_ids"
            case favorite
            case displayName = "display_name"
        }
        
        func toModel() -> Playlist {
            Playlist(
                name: name,
                liked: liked ?? false,
                cover: cover ?? "",
                trackIds: trackIds ?? [],
                favorite: favorite ?? false,
                displayName: displayName ?? "",
                favoriteSupported: favorite != nil
            )
        }
    }
    
    public func fetchPlaylists() async throws -> [Playlist] {
        let req = try makeRequest(endpoint: "api/v1/playlists")
        let dtos: [PlaylistDto] = try await execute(req)
        return dtos.map { $0.toModel() }
    }
    
    private struct LikesResponse: Codable {
        let trackIds: [String]?
        enum CodingKeys: String, CodingKey {
            case trackIds = "track_ids"
        }
    }
    
    public func fetchLikes() async throws -> [String] {
        let req = try makeRequest(endpoint: "api/v1/likes")
        let res: LikesResponse = try await execute(req)
        return res.trackIds ?? []
    }
    
    public func setLike(trackId: String, liked: Bool) async throws -> Bool {
        let payload = ["track_id": trackId, "liked": liked] as [String : Any]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let req = try makeRequest(endpoint: "api/v1/likes", method: "PUT", body: body)
        struct LikeResponse: Codable {
            let liked: Bool?
        }
        let res: LikeResponse = try await execute(req)
        return res.liked ?? liked
    }
    
    public func setPlaylistFavorite(name: String, favorite: Bool) async throws -> Bool {
        let payload = ["name": name, "favorite": favorite] as [String : Any]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let req = try makeRequest(endpoint: "api/v1/playlists/favorite", method: "PUT", body: body)
        struct FavResponse: Codable {
            let favorite: Bool?
        }
        let res: FavResponse = try await execute(req)
        return res.favorite ?? favorite
    }
    
    // Wire shape for Lyrics response
    private struct LyricsDto: Codable {
        let synced: String?
        let plain: String?
        
        func toModel() -> Lyrics {
            let parsedSynced = (synced?.isEmpty ?? true) ? [] : LrcParser.parse(lrc: synced!)
            return Lyrics(synced: parsedSynced, plain: plain ?? "")
        }
    }
    
    public func fetchLyrics(trackId: String) async throws -> Lyrics {
        let req = try makeRequest(endpoint: "api/v1/tracks/\(trackId)/lyrics")
        let dto: LyricsDto = try await execute(req)
        return dto.toModel()
    }
    
    // MARK: - Remote Catalog Search
    
    private struct RawRemoteSong: Codable {
        let id: String?
        let title: String?
        let artists: [String]?
        let artist: String?
        let album: String?
        let coverUrl: String?
        let cover: String?
        let duration: Double?
        let durationSeconds: Int?
        let url: String?
        
        enum CodingKeys: String, CodingKey {
            case id, title, artists, artist, album, url, duration
            case coverUrl = "cover_url"
            case cover
            case durationSeconds = "duration_seconds"
        }
        
        func toModel() -> RemoteSong {
            let arts = artists ?? (artist.map { [$0] } ?? [])
            return RemoteSong(
                id: id ?? UUID().uuidString,
                title: title ?? "Unknown Song",
                artists: arts,
                album: album ?? "",
                coverUrl: coverUrl ?? cover ?? "",
                durationSeconds: durationSeconds ?? Int(duration ?? 0),
                url: url ?? ""
            )
        }
    }
    
    private struct RawRemoteAlbum: Codable {
        let id: String?
        let title: String?
        let artist: String?
        let coverUrl: String?
        let cover: String?
        let year: String?
        let url: String?
        
        enum CodingKeys: String, CodingKey {
            case id, title, artist, year, url
            case coverUrl = "cover_url"
            case cover
        }
        
        func toModel() -> RemoteAlbum {
            RemoteAlbum(
                id: id ?? UUID().uuidString,
                title: title ?? "Unknown Album",
                artist: artist ?? "",
                coverUrl: coverUrl ?? cover ?? "",
                year: year ?? "",
                url: url ?? ""
            )
        }
    }
    
    public func searchCatalog(query: String) async throws -> CatalogSearchResult {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return CatalogSearchResult()
        }
        
        async let songsCall: [RawRemoteSong] = (try? execute(makeRequest(endpoint: "api/songs/search?query=\(encoded)"))) ?? []
        async let albumsCall: [RawRemoteAlbum] = (try? execute(makeRequest(endpoint: "api/albums/search?query=\(encoded)&limit=10"))) ?? []
        
        let (rawSongs, rawAlbums) = await (songsCall, albumsCall)
        return CatalogSearchResult(
            songs: rawSongs.map { $0.toModel() },
            albums: rawAlbums.map { $0.toModel() }
        )
    }
    
    // MARK: - Discover Endpoints
    
    private struct RawDiscoverArtist: Codable {
        let name: String
        let pictureUrl: String?
        let because: [String]?
        
        enum CodingKeys: String, CodingKey {
            case name
            case pictureUrl = "picture_url"
            case because
        }
        
        func toModel() -> DiscoverArtist {
            DiscoverArtist(name: name, pictureUrl: pictureUrl ?? "", because: because ?? [])
        }
    }
    
    private struct RawDiscoverArtistsResponse: Codable {
        let artists: [RawDiscoverArtist]?
    }
    
    private struct RawDiscoverAlbum: Codable {
        let name: String
        let artist: String?
        let year: String?
        let coverUrl: String?
        let url: String?
        let reason: String?
        let because: [String]?
        
        enum CodingKeys: String, CodingKey {
            case name, artist, year, url, reason, because
            case coverUrl = "cover_url"
        }
        
        func toModel() -> DiscoverAlbum {
            DiscoverAlbum(
                name: name,
                artist: artist ?? "",
                year: year ?? "",
                coverUrl: coverUrl ?? "",
                url: url ?? "",
                reason: reason ?? "",
                because: because ?? []
            )
        }
    }
    
    private struct RawDiscoverPlaylist: Codable {
        let name: String
        let owner: String?
        let coverUrl: String?
        let url: String?
        let reason: String?
        let artist: String?
        
        enum CodingKeys: String, CodingKey {
            case name, owner, url, reason, artist
            case coverUrl = "cover_url"
        }
        
        func toModel() -> DiscoverPlaylist {
            DiscoverPlaylist(
                name: name,
                owner: owner ?? "",
                coverUrl: coverUrl ?? "",
                url: url ?? "",
                reason: reason ?? "",
                artist: artist ?? ""
            )
        }
    }
    
    private struct RawDiscoverCollectionsResponse: Codable {
        let albums: [RawDiscoverAlbum]?
        let moreAlbums: [RawDiscoverAlbum]?
        let playlists: [RawDiscoverPlaylist]?
        let artistUrls: [String: String]?
        let partial: Bool?
        
        enum CodingKeys: String, CodingKey {
            case albums, playlists, partial
            case moreAlbums = "more_albums"
            case artistUrls = "artist_urls"
        }
    }
    
    public func fetchDiscover(artistSeeds: [String]) async throws -> (artists: [DiscoverArtist], collections: DiscoverCollections) {
        let seedList = artistSeeds.prefix(15).map { ["name": $0, "tracks": 5, "liked": 2] }
        let body = try JSONSerialization.data(withJSONObject: ["library": seedList])
        
        let artistsReq = try makeRequest(endpoint: "api/discover", method: "POST", body: body)
        let collectionsReq = try makeRequest(endpoint: "api/discover/collections", method: "POST", body: body)
        
        async let artistsCall: RawDiscoverArtistsResponse? = try? execute(artistsReq)
        async let collectionsCall: RawDiscoverCollectionsResponse? = try? execute(collectionsReq)
        
        let (rawArtists, rawCollections) = await (artistsCall, collectionsCall)
        
        let artists = rawArtists?.artists?.map { $0.toModel() } ?? []
        let collections = DiscoverCollections(
            albums: rawCollections?.albums?.map { $0.toModel() } ?? [],
            moreAlbums: rawCollections?.moreAlbums?.map { $0.toModel() } ?? [],
            playlists: rawCollections?.playlists?.map { $0.toModel() } ?? [],
            artistUrls: rawCollections?.artistUrls ?? [:],
            partial: rawCollections?.partial ?? false
        )
        return (artists, collections)
    }
    
    // MARK: - Podcast Endpoints
    
    private struct RawPodcastShow: Codable {
        let id: Int64
        let name: String
        let author: String?
        let description: String?
        let artworkUrl: String?
        let episodeCount: Int?
        let downloadedCount: Int?
        
        enum CodingKeys: String, CodingKey {
            case id, name, author, description
            case artworkUrl = "artwork_url"
            case episodeCount = "episode_count"
            case downloadedCount = "downloaded_count"
        }
        
        func toModel() -> PodcastShow {
            PodcastShow(
                id: id,
                name: name,
                author: author ?? "",
                description: description ?? "",
                artworkUrl: artworkUrl ?? "",
                episodeCount: episodeCount ?? 0,
                downloadedCount: downloadedCount ?? 0
            )
        }
    }
    
    private struct RawPodcastEpisode: Codable {
        let id: Int64
        let showId: Int64?
        let title: String?
        let description: String?
        let publishedAt: String?
        let durationSeconds: Double?
        let seasonNumber: Int?
        let episodeNumber: Int?
        let filename: String?
        let positionSeconds: Double?
        let played: Bool?
        
        enum CodingKeys: String, CodingKey {
            case id, title, description, filename, played
            case showId = "show_id"
            case publishedAt = "published_at"
            case durationSeconds = "duration_seconds"
            case seasonNumber = "season_number"
            case episodeNumber = "episode_number"
            case positionSeconds = "position_seconds"
        }
        
        func toModel(fallbackShowId: Int64) -> PodcastEpisode {
            PodcastEpisode(
                id: id,
                showId: showId ?? fallbackShowId,
                title: title ?? "Untitled Episode",
                description: description ?? "",
                publishedAt: publishedAt ?? "",
                durationSeconds: Int(durationSeconds ?? 0),
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber,
                filename: filename,
                positionSeconds: positionSeconds ?? 0,
                played: played ?? false
            )
        }
    }
    
    private struct RawPodcastEpisodesResponse: Codable {
        let episodes: [RawPodcastEpisode]?
    }
    
    public func fetchPodcastShows() async throws -> [PodcastShow] {
        let req = try makeRequest(endpoint: "api/podcasts/shows")
        let rawShows: [RawPodcastShow] = try await execute(req)
        return rawShows.map { $0.toModel() }
    }
    
    public func fetchPodcastEpisodes(showId: Int64) async throws -> [PodcastEpisode] {
        let req = try makeRequest(endpoint: "api/podcasts/shows/\(showId)/episodes")
        let response: RawPodcastEpisodesResponse = try await execute(req)
        return (response.episodes ?? []).map { $0.toModel(fallbackShowId: showId) }
    }
    
    public func updateEpisodePlayback(episodeId: Int64, progress: EpisodeProgress) async throws {
        let payload: [String: Any] = [
            "position_seconds": progress.positionSeconds,
            "played": progress.played
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let req = try makeRequest(endpoint: "api/podcasts/episodes/\(episodeId)/playback", method: "PUT", body: body)
        let _: Data = try await urlSession.data(for: req).0
    }
    
    // MARK: - Trash Endpoints
    
    private struct RawTrashCapabilities: Codable {
        let enabled: Bool?
        let canManage: Bool?
        let retentionDays: Int?
        
        enum CodingKeys: String, CodingKey {
            case enabled
            case canManage = "can_manage"
            case retentionDays = "retention_days"
        }
        
        func toModel() -> TrashCapability {
            TrashCapability(
                enabled: enabled ?? true,
                canManage: canManage ?? true,
                retentionDays: retentionDays ?? 30
            )
        }
    }
    
    private struct RawTrashItemMetadata: Codable {
        let title: String?
        let artist: String?
        let codec: String?
    }
    
    private struct RawTrashItem: Codable {
        let id: String
        let file: String?
        let trackId: String?
        let metadata: RawTrashItemMetadata?
        let state: String?
        let size: Int64?
        let expiresAt: Double?
        let error: String?
        
        enum CodingKeys: String, CodingKey {
            case id, file, state, size, error, metadata
            case trackId = "track_id"
            case expiresAt = "expires_at"
        }
        
        func toModel() -> TrashItem {
            let trashState = TrashState(rawValue: state ?? "") ?? .trashed
            let expiryDate = expiresAt.map { Date(timeIntervalSince1970: $0) }
            return TrashItem(
                id: id,
                file: file ?? "",
                trackId: trackId ?? "",
                title: metadata?.title ?? "",
                artist: metadata?.artist ?? "",
                codec: metadata?.codec ?? "",
                state: trashState,
                size: size ?? 0,
                expiresAt: expiryDate,
                error: error ?? ""
            )
        }
    }
    
    private struct RawTrashListing: Codable {
        let items: [RawTrashItem]?
        let total: Int?
        let size: Int64?
        
        func toModel() -> TrashPage {
            TrashPage(
                items: (items ?? []).map { $0.toModel() },
                total: total ?? (items?.count ?? 0),
                bytes: size ?? 0
            )
        }
    }
    
    public func fetchTrashCapabilities() async throws -> TrashCapability {
        let req = try makeRequest(endpoint: "api/v1/library/trash/capabilities")
        let dto: RawTrashCapabilities = try await execute(req)
        return dto.toModel()
    }
    
    public func fetchTrashList(offset: Int = 0, limit: Int = 50, search: String = "") async throws -> TrashPage {
        let query = "offset=\(offset)&limit=\(limit)&search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        let req = try makeRequest(endpoint: "api/v1/library/trash?\(query)")
        let dto: RawTrashListing = try await execute(req)
        return dto.toModel()
    }
    
    public func restoreTrashItems(ids: [String]) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["ids": ids])
        let req = try makeRequest(endpoint: "api/v1/library/trash/restore", method: "POST", body: body)
        let _: Data = try await urlSession.data(for: req).0
    }
    
    public func retryTrashItems(ids: [String]) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["ids": ids])
        let req = try makeRequest(endpoint: "api/v1/library/trash/retry", method: "POST", body: body)
        let _: Data = try await urlSession.data(for: req).0
    }
    
    // MARK: - Media URLs
    public func coverUrl(trackId: String, size: Int = 300) -> URL? {
        guard let session = sessionStore.session else { return nil }
        let cleanBase = session.baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(cleanBase)/api/v1/tracks/\(trackId)/cover?size=\(size)")
    }
    
    public func playlistCoverUrl(path: String) -> URL? {
        guard let session = sessionStore.session, !path.isEmpty else { return nil }
        let cleanBase = session.baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
        return URL(string: "\(cleanBase)/playlist-cover?file=\(encoded)")
    }
    
    public func podcastEpisodeStreamUrl(episodeId: Int64) -> URL? {
        guard let session = sessionStore.session else { return nil }
        let cleanBase = session.baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(cleanBase)/api/podcasts/episodes/\(episodeId)/stream")
    }
    
    public func streamUrl(trackId: String) -> URL? {
        if trackId.hasPrefix("http://") || trackId.hasPrefix("https://") {
            return URL(string: trackId)
        }
        if trackId.hasPrefix("podcast_"), let epId = Int64(trackId.replacingOccurrences(of: "podcast_", with: "")) {
            return podcastEpisodeStreamUrl(episodeId: epId)
        }
        guard let session = sessionStore.session else { return nil }
        let cleanBase = session.baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(cleanBase)/api/v1/tracks/\(trackId)/stream")
    }
}
