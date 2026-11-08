import Foundation

public enum ServerAddress {
    public static let defaultPort = 8000
    
    public static func normalize(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        if !text.contains("://") {
            text = "http://" + text
        }
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let portPart = (url.port != nil) ? ":\(url.port!)" : ""
        let hostPart = (host.contains(":") && !host.hasPrefix("[")) ? "[\(host)]" : host
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathPart = path.isEmpty ? "" : "/\(path)"
        return "\(scheme)://\(hostPart)\(portPart)\(pathPart)"
    }
    
    public static func candidates(_ input: String) -> [String] {
        guard let base = normalize(input), let url = URL(string: base) else { return [] }
        let typedScheme = input.contains("://")
        if url.port == nil && url.scheme == "http" {
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            comps?.port = defaultPort
            if let withPort = comps?.url?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) {
                return typedScheme ? [base, withPort] : [withPort, base]
            }
        }
        return [base]
    }
    
    public static func isCleartextBeyondLan(_ baseUrl: String) -> Bool {
        guard let url = URL(string: baseUrl), url.scheme == "http", let host = url.host else {
            return false
        }
        return !isLocalHost(host.trimmingCharacters(in: CharacterSet(charactersIn: "[]")))
    }
    
    public static func isLocalHost(_ host: String) -> Bool {
        let lower = host.lowercased()
        if lower == "localhost" { return true }
        let localSuffixes = [".local", ".lan", ".home.arpa", ".internal", ".localdomain"]
        if localSuffixes.contains(where: { lower.hasSuffix($0) }) { return true }
        if !lower.contains(".") { return true }
        
        let parts = lower.split(separator: ".").compactMap { Int($0) }
        if parts.count == 4 {
            if parts[0] == 10 { return true }
            if parts[0] == 127 { return true }
            if parts[0] == 192 && parts[1] == 168 { return true }
            if parts[0] == 172 && (16...31).contains(parts[1]) { return true }
            if parts[0] == 100 && (64...127).contains(parts[1]) { return true }
        }
        return false
    }
}
