import Foundation

public enum LiveEvent: Equatable {
    case connected
    case libraryChanged
    case likesChanged
    case queueReload
    case refused(closeCode: Int?, httpStatus: Int?)
}

@MainActor
public class LiveUpdatesClient: ObservableObject {
    public static let shared = LiveUpdatesClient()
    
    @Published public private(set) var isConnected = false
    
    public var onLibraryChanged: (() -> Void)?
    public var onLikesChanged: (() -> Void)?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var isRunning = false
    private let clientId = UUID().uuidString
    
    public init() {}
    
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        connect()
    }
    
    public func stop() {
        isRunning = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }
    
    private func connect() {
        guard isRunning, let session = KeychainSessionStore.shared.session else { return }
        
        let wsScheme = session.baseUrl.hasPrefix("https://") ? "wss://" : "ws://"
        let hostPart = session.baseUrl.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
        let cleanHost = hostPart.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        guard let url = URL(string: "\(wsScheme)\(cleanHost)/api/ws?client_id=\(clientId)") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.webSocketTask(with: request)
        self.webSocketTask = task
        task.resume()
        
        self.isConnected = true
        receiveMessage()
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self, self.isRunning else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleText(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleText(text)
                        }
                    @unknown default:
                        break
                    }
                    self.receiveMessage()
                    
                case .failure(let error):
                    print("LiveUpdates WebSocket error: \(error.localizedDescription)")
                    self.isConnected = false
                    // Reconnect after delay if still running
                    if self.isRunning {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        self.connect()
                    }
                }
            }
        }
    }
    
    private func handleText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }
        
        switch type {
        case "library_changed":
            onLibraryChanged?()
        case "likes":
            onLikesChanged?()
        default:
            break
        }
    }
}
