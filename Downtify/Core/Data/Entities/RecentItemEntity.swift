import Foundation
import SwiftData

@Model
public final class RecentItemEntity {
    @Attribute(.unique) public var key: String
    public var type: String
    public var refId: String
    public var title: String
    public var subtitle: String
    public var coverTrackId: String?
    public var playedAt: Date
    
    public init(
        key: String,
        type: String,
        refId: String,
        title: String,
        subtitle: String,
        coverTrackId: String? = nil,
        playedAt: Date = Date()
    ) {
        self.key = key
        self.type = type
        self.refId = refId
        self.title = title
        self.subtitle = subtitle
        self.coverTrackId = coverTrackId
        self.playedAt = playedAt
    }
}
