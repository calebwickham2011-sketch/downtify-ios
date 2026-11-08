import Foundation

public struct ServerInfo: Codable, Equatable, Hashable {
    public let serverId: String
    public let name: String
    public let product: String
    public let version: String
    public let apiVersion: Int
    public let requireSignIn: Bool
    public let capabilities: Capabilities
    
    public enum Compatibility {
        case ok
        case notDowntify
        case tooNew
    }
    
    public var compatibility: Compatibility {
        if product != "Downtify" { return .notDowntify }
        if apiVersion > 1 { return .tooNew }
        return .ok
    }
    
    public init(
        serverId: String = "",
        name: String = "",
        product: String = "Downtify",
        version: String = "",
        apiVersion: Int = 1,
        requireSignIn: Bool = false,
        capabilities: Capabilities = Capabilities()
    ) {
        self.serverId = serverId
        self.name = name
        self.product = product
        self.version = version
        self.apiVersion = apiVersion
        self.requireSignIn = requireSignIn
        self.capabilities = capabilities
    }
    
    enum CodingKeys: String, CodingKey {
        case serverId = "server_id"
        case name
        case product
        case version
        case apiVersion = "api_version"
        case requireSignIn = "require_sign_in"
        case capabilities
    }
}

public struct Capabilities: Codable, Equatable, Hashable {
    public let transcoding: Transcoding
    public let signedUrls: Bool
    public let pairing: Bool
    public let podcasts: Bool
    public let discover: Bool
    public let lyrics: Bool
    public let librarySync: Bool
    public let passwordSignIn: Bool
    
    public init(
        transcoding: Transcoding = Transcoding(),
        signedUrls: Bool = false,
        pairing: Bool = false,
        podcasts: Bool = false,
        discover: Bool = false,
        lyrics: Bool = false,
        librarySync: Bool = false,
        passwordSignIn: Bool = false
    ) {
        self.transcoding = transcoding
        self.signedUrls = signedUrls
        self.pairing = pairing
        self.podcasts = podcasts
        self.discover = discover
        self.lyrics = lyrics
        self.librarySync = librarySync
        self.passwordSignIn = passwordSignIn
    }
    
    enum CodingKeys: String, CodingKey {
        case transcoding
        case signedUrls = "signed_urls"
        case pairing
        case podcasts
        case discover
        case lyrics
        case librarySync = "library_sync"
        case passwordSignIn = "password_sign_in"
    }
}

public struct Transcoding: Codable, Equatable, Hashable {
    public let available: Bool
    public let formats: [String]
    public let bitrates: [Int]
    
    public init(available: Bool = false, formats: [String] = [], bitrates: [Int] = []) {
        self.available = available
        self.formats = formats
        self.bitrates = bitrates
    }
}
