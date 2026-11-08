import Foundation
import Network

public struct DiscoveredServer: Identifiable, Equatable, Hashable {
    public var id: String { serverId.isEmpty ? baseUrl : serverId }
    public let serviceName: String
    public let serverId: String
    public let name: String
    public let version: String
    public let apiVersion: Int
    public let baseUrl: String
    
    public var address: String {
        if let range = baseUrl.range(of: "://") {
            return String(baseUrl[range.upperBound...])
        }
        return baseUrl
    }
}

@MainActor
public class ServerDiscovery: ObservableObject {
    public static let shared = ServerDiscovery()
    
    @Published public private(set) var servers: [DiscoveredServer] = []
    @Published public private(set) var isSearching = false
    
    private var browser: NWBrowser?
    private var discoveredMap: [String: DiscoveredServer] = [:]
    
    public init() {}
    
    public func start() {
        stop()
        discoveredMap.removeAll()
        servers = []
        isSearching = true
        
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_downtify._tcp", domain: nil)
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        let b = NWBrowser(for: descriptor, using: parameters)
        b.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor [weak self] in
                self?.handleResults(results)
            }
        }
        b.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .ready:
                    self?.isSearching = true
                case .failed(let err):
                    print("ServerDiscovery failed: \(err)")
                    self?.isSearching = false
                case .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }
        b.start(queue: .main)
        self.browser = b
    }
    
    public func stop() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }
    
    private func handleResults(_ results: Set<NWBrowser.Result>) {
        discoveredMap.removeAll()
        for result in results {
            if case .service(let name, _, _, _) = result.endpoint {
                var serverId = ""
                var version = ""
                var apiVersion = 1
                var port = 8000
                var scheme = "http"
                var path = ""
                
                if case .bonjour(let txtRecord) = result.metadata {
                    let dict = txtRecord.dictionary
                    if let sid = dict["id"] { serverId = sid }
                    if let v = dict["version"] { version = v }
                    if let api = dict["api"], let a = Int(api) { apiVersion = a }
                    if let p = dict["port"], let parsedPort = Int(p) { port = parsedPort }
                    if let s = dict["scheme"] { scheme = s }
                    if let pth = dict["path"] { path = pth.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
                }
                
                let host = name + ".local"
                let pathPart = path.isEmpty ? "" : "/\(path)"
                let baseUrl = "\(scheme)://\(host):\(port)\(pathPart)"
                
                let server = DiscoveredServer(
                    serviceName: name,
                    serverId: serverId,
                    name: name,
                    version: version,
                    apiVersion: apiVersion,
                    baseUrl: baseUrl
                )
                discoveredMap[server.id] = server
            }
        }
        servers = Array(discoveredMap.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
