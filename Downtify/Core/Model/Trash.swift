import Foundation

public enum TrashState: String, Codable, Equatable {
    case pending = "pending"
    case moving = "moving"
    case trashed = "trashed"
    case restorePending = "restore_pending"
    case restoring = "restoring"
    case restored = "restored"
    case purging = "purging"
    case purged = "purged"
    case error = "error"
    case unknown = ""
    
    public var label: String {
        switch self {
        case .pending, .moving: return "Moving to Trash"
        case .trashed: return "Trashed"
        case .restorePending, .restoring: return "Restoring"
        case .restored: return "Restored"
        case .purging, .purged: return "Purged"
        case .error: return "Error"
        case .unknown: return "Unknown"
        }
    }
}

/// One track in the server's music trash.
public struct TrashItem: Identifiable, Equatable, Hashable {
    public let id: String
    public let file: String
    public let trackId: String
    public let title: String
    public let artist: String
    public let codec: String
    public let state: TrashState
    public let size: Int64
    public let expiresAt: Date?
    public let error: String
    
    public var displayTitle: String {
        if !title.isEmpty { return title }
        return (file as NSString).lastPathComponent
    }
    
    public var format: String {
        if !codec.isEmpty { return codec.uppercased() }
        let ext = (file as NSString).pathExtension
        return ext.isEmpty ? "AUDIO" : ext.uppercased()
    }
    
    public var isRestorable: Bool {
        (state == .trashed || state == .pending || state == .error) &&
        (expiresAt == nil || expiresAt! > Date())
    }
    
    public init(
        id: String,
        file: String,
        trackId: String = "",
        title: String = "",
        artist: String = "",
        codec: String = "",
        state: TrashState = .trashed,
        size: Int64 = 0,
        expiresAt: Date? = nil,
        error: String = ""
    ) {
        self.id = id
        self.file = file
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.codec = codec
        self.state = state
        self.size = size
        self.expiresAt = expiresAt
        self.error = error
    }
}

public struct TrashCapability: Equatable {
    public let enabled: Bool
    public let canManage: Bool
    public let retentionDays: Int
    
    public init(enabled: Bool = true, canManage: Bool = true, retentionDays: Int = 30) {
        self.enabled = enabled
        self.canManage = canManage
        self.retentionDays = retentionDays
    }
}

public struct TrashPage: Equatable {
    public let items: [TrashItem]
    public let total: Int
    public let bytes: Int64
    
    public init(items: [TrashItem] = [], total: Int = 0, bytes: Int64 = 0) {
        self.items = items
        self.total = total
        self.bytes = bytes
    }
}
