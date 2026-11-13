import Foundation
import SwiftData
import SwiftUI

@MainActor
public class LibraryRepository: ObservableObject {
    public static let shared = LibraryRepository()
    
    public let modelContainer: ModelContainer
    public var modelContext: ModelContext { modelContainer.mainContext }
    
    @Published public private(set) var tracks: [Track] = []
    @Published public private(set) var albums: [Album] = []
    @Published public private(set) var artists: [Artist] = []
    @Published public private(set) var playlists: [Playlist] = []
    @Published public private(set) var likedTrackIds: Set<String> = []
    @Published public private(set) var recentItems: [RecentItemEntity] = []
    
    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var lastSyncDate: Date? = nil
    @Published public private(set) var syncError: String? = nil
    
    private let api = DowntifyAPI.shared
    
    private init() {
        do {
            let schema = Schema([
                TrackEntity.self,
                AlbumEntity.self,
                ArtistEntity.self,
                PlaylistEntity.self,
                RecentItemEntity.self,
                SyncMetaEntity.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error)")
        }
        
        loadLocalData()
        
        LiveUpdatesClient.shared.onLibraryChanged = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.syncWithServer()
            }
        }
        LiveUpdatesClient.shared.onLikesChanged = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.syncLikesWithServer()
            }
        }
    }
    
    // MARK: - Instant Offline Load
    public func loadLocalData() {
        let descriptor = FetchDescriptor<TrackEntity>()
        if let entities = try? modelContext.fetch(descriptor) {
            let models = entities.map { $0.toModel() }
            self.tracks = models
            self.albums = LibraryGrouping.albums(from: models)
            self.artists = LibraryGrouping.artists(from: models)
            self.likedTrackIds = Set(entities.filter { $0.isLiked }.map { $0.id })
        }
        
        let playlistDescriptor = FetchDescriptor<PlaylistEntity>(sortBy: [SortDescriptor(\PlaylistEntity.position)])
        if let playlistEntities = try? modelContext.fetch(playlistDescriptor) {
            self.playlists = playlistEntities.map { $0.toModel() }
        }
        
        let recentDescriptor = FetchDescriptor<RecentItemEntity>(sortBy: [SortDescriptor(\RecentItemEntity.playedAt, order: .reverse)])
        if let recentEntities = try? modelContext.fetch(recentDescriptor) {
            self.recentItems = Array(recentEntities.prefix(20))
        }
        
        let metaDescriptor = FetchDescriptor<SyncMetaEntity>()
        if let meta = try? modelContext.fetch(metaDescriptor).first {
            self.lastSyncDate = meta.lastSyncedAt
        }
    }
    
    // MARK: - Delta Sync with Downtify Server
    public func syncWithServer(forceFull: Bool = false) async {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil
        
        let currentServerId = KeychainSessionStore.shared.session?.serverId ?? "default"
        var meta = try? modelContext.fetch(FetchDescriptor<SyncMetaEntity>()).first
        if meta == nil {
            let newMeta = SyncMetaEntity(serverId: currentServerId, cursor: 0)
            modelContext.insert(newMeta)
            meta = newMeta
        }
        
        let cursorToFetch = forceFull ? 0 : (meta?.cursor ?? 0)
        
        do {
            async let fetchedLibrary = api.fetchLibrary(since: cursorToFetch)
            async let fetchedPlaylists = api.fetchPlaylists()
            async let fetchedLikes = api.fetchLikes()
            
            let (libResult, playlistsResult, likesResult) = try await (fetchedLibrary, fetchedPlaylists, fetchedLikes)
            let likesSet = Set(likesResult)
            
            // Update Tracks
            if libResult.full || cursorToFetch == 0 {
                try? modelContext.delete(model: TrackEntity.self)
                for t in libResult.tracks {
                    let entity = TrackEntity(from: t, isLiked: likesSet.contains(t.id))
                    modelContext.insert(entity)
                }
            } else {
                for id in libResult.deleted {
                    let toDeleteDesc = FetchDescriptor<TrackEntity>(predicate: #Predicate { $0.id == id })
                    if let existing = try? modelContext.fetch(toDeleteDesc).first {
                        modelContext.delete(existing)
                    }
                }
                for t in libResult.tracks {
                    let toUpdateDesc = FetchDescriptor<TrackEntity>(predicate: #Predicate { $0.id == t.id })
                    if let existing = try? modelContext.fetch(toUpdateDesc).first {
                        modelContext.delete(existing)
                    }
                    let entity = TrackEntity(from: t, isLiked: likesSet.contains(t.id))
                    modelContext.insert(entity)
                }
            }
            
            // Update Playlists
            try? modelContext.delete(model: PlaylistEntity.self)
            for (idx, p) in playlistsResult.enumerated() {
                let entity = PlaylistEntity(from: p, position: idx)
                modelContext.insert(entity)
            }
            
            // Rebuild Album + Artist denormalized caches from track data
            let allTracks = libResult.tracks.isEmpty && cursorToFetch != 0
                ? (try? modelContext.fetch(FetchDescriptor<TrackEntity>()))?.map { $0.toModel() } ?? []
                : libResult.tracks
            let rebuiltAlbums = LibraryGrouping.albums(from: allTracks)
            let rebuiltArtists = LibraryGrouping.artists(from: allTracks)
            
            try? modelContext.delete(model: AlbumEntity.self)
            for album in rebuiltAlbums {
                modelContext.insert(AlbumEntity(from: album))
            }
            try? modelContext.delete(model: ArtistEntity.self)
            for artist in rebuiltArtists {
                modelContext.insert(ArtistEntity(from: artist))
            }
            
            // Update Sync Meta
            meta?.cursor = libResult.cursor
            meta?.lastSyncedAt = Date()
            try? modelContext.save()
            
            loadLocalData()
            self.lastSyncDate = Date()
            self.isSyncing = false
        } catch {
            self.isSyncing = false
            self.syncError = error.localizedDescription
            print("LibraryRepository sync error: \(error)")
        }
    }
    
    public func syncLikesWithServer() async {
        do {
            let likes = try await api.fetchLikes()
            let likesSet = Set(likes)
            self.likedTrackIds = likesSet
            
            let descriptor = FetchDescriptor<TrackEntity>()
            if let entities = try? modelContext.fetch(descriptor) {
                for e in entities {
                    e.isLiked = likesSet.contains(e.id)
                }
                try? modelContext.save()
            }
        } catch {
            print("Failed to sync likes: \(error)")
        }
    }
    
    // MARK: - Optimistic Likes & Favorites
    public func toggleLike(trackId: String) async {
        let isCurrentlyLiked = likedTrackIds.contains(trackId)
        let target = !isCurrentlyLiked
        
        if target {
            likedTrackIds.insert(trackId)
        } else {
            likedTrackIds.remove(trackId)
        }
        
        let desc = FetchDescriptor<TrackEntity>(predicate: #Predicate { $0.id == trackId })
        if let entity = try? modelContext.fetch(desc).first {
            entity.isLiked = target
            try? modelContext.save()
        }
        
        do {
            _ = try await api.setLike(trackId: trackId, liked: target)
        } catch {
            if isCurrentlyLiked {
                likedTrackIds.insert(trackId)
            } else {
                likedTrackIds.remove(trackId)
            }
            if let entity = try? modelContext.fetch(desc).first {
                entity.isLiked = isCurrentlyLiked
                try? modelContext.save()
            }
        }
    }
    
    public func togglePlaylistFavorite(playlist: Playlist) async {
        let target = !playlist.favorite
        let playlistName = playlist.name
        
        let desc = FetchDescriptor<PlaylistEntity>(predicate: #Predicate { $0.name == playlistName })
        if let entity = try? modelContext.fetch(desc).first {
            entity.favorite = target
            try? modelContext.save()
        }
        loadLocalData()
        
        do {
            _ = try await api.setPlaylistFavorite(name: playlist.name, favorite: target)
        } catch {
            print("Failed to update playlist favorite: \(error)")
        }
    }
    
    // MARK: - Recent Playback
    public func recordRecent(type: String, refId: String, title: String, subtitle: String, coverTrackId: String?) {
        let key = "\(type):\(refId)"
        let desc = FetchDescriptor<RecentItemEntity>(predicate: #Predicate { $0.key == key })
        if let existing = try? modelContext.fetch(desc).first {
            existing.playedAt = Date()
        } else {
            let item = RecentItemEntity(key: key, type: type, refId: refId, title: title, subtitle: subtitle, coverTrackId: coverTrackId)
            modelContext.insert(item)
        }
        try? modelContext.save()
        
        let recentDescriptor = FetchDescriptor<RecentItemEntity>(sortBy: [SortDescriptor(\RecentItemEntity.playedAt, order: .reverse)])
        if let recentEntities = try? modelContext.fetch(recentDescriptor) {
            self.recentItems = Array(recentEntities.prefix(20))
        }
    }
}
