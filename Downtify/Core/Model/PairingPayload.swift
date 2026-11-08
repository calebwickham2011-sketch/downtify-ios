import Foundation

public struct PairingPayload: Equatable, Hashable {
    public let baseUrl: String
    public let serverId: String
    public let code: String
    
    public init(baseUrl: String, serverId: String, code: String) {
        self.baseUrl = baseUrl
        self.serverId = serverId
        self.code = code
    }
    
    public static func parse(_ text: String) -> PairingPayload? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let comps = URLComponents(string: trimmed),
              let scheme = comps.scheme?.lowercased(), scheme == "downtify",
              let host = comps.host?.lowercased(), host == "pair" else {
            return nil
        }
        guard let queryItems = comps.queryItems else { return nil }
        var dict: [String: String] = [:]
        for item in queryItems {
            if let val = item.value {
                dict[item.name] = val
            }
        }
        guard let rawUrl = dict["url"],
              let normalizedUrl = ServerAddress.normalize(rawUrl),
              let sid = dict["sid"]?.trimmingCharacters(in: .whitespacesAndNewlines), !sid.isEmpty,
              let code = dict["code"]?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty else {
            return nil
        }
        return PairingPayload(baseUrl: normalizedUrl, serverId: sid, code: code)
    }
}
