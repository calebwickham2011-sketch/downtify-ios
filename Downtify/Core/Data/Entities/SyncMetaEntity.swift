import Foundation
import SwiftData

@Model
public final class SyncMetaEntity {
    @Attribute(.unique) public var serverId: String
    public var cursor: Int64
    public var lastSyncedAt: Date
    public var revisionHash: String
    
    public init(
        serverId: String,
        cursor: Int64 = 0,
        lastSyncedAt: Date = Date(),
        revisionHash: String = ""
    ) {
        self.serverId = serverId
        self.cursor = cursor
        self.lastSyncedAt = lastSyncedAt
        self.revisionHash = revisionHash
    }
}
