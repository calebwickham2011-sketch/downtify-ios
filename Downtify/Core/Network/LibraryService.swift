import Foundation
import SwiftUI

@MainActor
public class LibraryService: ObservableObject {
    public static let shared = LibraryService()
    
    @Published public private(set) var tracks: [Track] = []
    @Published public private(set) var albums: [Album] = []
    @Published public private(set) var artists: [Artist] = []
    @Published public private(set) var playlists: [Playlist] = []
    @Published public private(set) var likedTrackIds: Set<String> = []
    
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var lastSyncDate: Date?
    
    private let api = DowntifyAPI.shared
    private let liveUpdates = LiveUpdatesClient.shared
    
    public init() {
        // Register WebSocket live updates triggers
        liveUpdates.onLibraryChanged = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.refreshLibrary()
            }
        }
        liveUpdates.onLikesChanged = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.refreshLikes()
            }
        }
    }
    
    public func startLiveSync() {
        liveUpdates.start()
    }
    
    public func stopLiveSync() {
        liveUpdates.stop()
    }
    
    public func refreshLibrary() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            async let fetchedLibrary = api.fetchLibrary(since: 0)
            async let fetchedPlaylists = api.fetchPlaylists()
            async let fetchedLikes = api.fetchLikes()
            
            let (libResult, playlistsResult, likesResult) = try await (fetchedLibrary, fetchedPlaylists, fetchedLikes)
            
            self.tracks = libResult.tracks
            self.albums = LibraryGrouping.albums(from: libResult.tracks)
            self.artists = LibraryGrouping.artists(from: libResult.tracks)
            self.playlists = playlistsResult
            self.likedTrackIds = Set(likesResult)
            self.lastSyncDate = Date()
            self.isLoading = false
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            print("LibraryService refresh error: \(error)")
        }
    }
    
    public func refreshLikes() async {
        do {
            let likes = try await api.fetchLikes()
            self.likedTrackIds = Set(likes)
        } catch {
            print("Failed to refresh likes: \(error)")
        }
    }
    
    public func toggleLike(trackId: String) async {
        let isCurrentlyLiked = likedTrackIds.contains(trackId)
        let target = !isCurrentlyLiked
        
        // Optimistic update
        if target {
            likedTrackIds.insert(trackId)
        } else {
            likedTrackIds.remove(trackId)
        }
        
        do {
            _ = try await api.setLike(trackId: trackId, liked: target)
        } catch {
            // Rollback on failure
            if isCurrentlyLiked {
                likedTrackIds.insert(trackId)
            } else {
                likedTrackIds.remove(trackId)
            }
        }
    }
    
    public func togglePlaylistFavorite(playlist: Playlist) async {
        let target = !playlist.favorite
        do {
            _ = try await api.setPlaylistFavorite(name: playlist.name, favorite: target)
            if let index = playlists.firstIndex(where: { $0.name == playlist.name }) {
                let updated = Playlist(
                    name: playlist.name,
                    liked: playlist.liked,
                    cover: playlist.cover,
                    trackIds: playlist.trackIds,
                    favorite: target,
                    displayName: playlist.displayName,
                    favoriteSupported: true
                )
                playlists[index] = updated
            }
        } catch {
            print("Failed to toggle playlist favorite: \(error)")
        }
    }
}
