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
    
    public func streamUrl(trackId: String) -> URL? {
        guard let session = sessionStore.session else { return nil }
        let cleanBase = session.baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(cleanBase)/api/v1/tracks/\(trackId)/stream")
    }
}
