import Foundation

public struct Session: Codable, Equatable, Hashable, Sendable {
    public let baseUrl: String
    public let serverId: String
    public let serverName: String
    public let deviceId: String
    public let token: String
    public let username: String
    
    public init(
        baseUrl: String,
        serverId: String,
        serverName: String,
        deviceId: String,
        token: String,
        username: String = ""
    ) {
        self.baseUrl = baseUrl
        self.serverId = serverId
        self.serverName = serverName
        self.deviceId = deviceId
        self.token = token
        self.username = username
    }
}

public enum SignOutReason: String, Codable, Sendable {
    case user
    case revoked
}
