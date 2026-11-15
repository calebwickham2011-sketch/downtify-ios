import Foundation
import Combine
import UIKit

public enum DownloadState: Equatable {
    case queued
    case downloading
    case completed
    case failed(String)
}

public struct DownloadProgress: Equatable {
    public var progress: Double // 0.0 to 1.0
    public var bytesWritten: Int64
    public var totalBytes: Int64
    public var state: DownloadState
    
    public init(progress: Double = 0, bytesWritten: Int64 = 0, totalBytes: Int64 = 0, state: DownloadState = .queued) {
        self.progress = progress
        self.bytesWritten = bytesWritten
        self.totalBytes = totalBytes
        self.state = state
    }
}

public struct OfflineTrackInfo: Codable, Identifiable {
    public var id: String { trackId }
    public let trackId: String
    public let title: String
    public let artist: String
    public let album: String
    public let albumId: String
    public let duration: Double
    public let fileName: String
    public let fileSize: Int64
    public let downloadedAt: Date
    public let codec: String
}

/// Central manager for offline track downloading, background transfers, and local storage.
@MainActor
public final class OfflineDownloadManager: NSObject, ObservableObject {
    public static let shared = OfflineDownloadManager()
    
    // Published states for UI observers
    @Published public private(set) var downloadedTrackIds: Set<String> = []
    @Published public private(set) var activeDownloads: [String: DownloadProgress] = [:]
    @Published public private(set) var totalAudioBytes: Int64 = 0
    @Published public var storageQuotaGB: Double {
        didSet {
            UserDefaults.standard.set(storageQuotaGB, forKey: "downtify_storage_quota_gb")
        }
    }
    
    private let offlineDir: URL
    private let metadataFile: URL
    private var metadataRegistry: [String: OfflineTrackInfo] = [:]
    
    // Tasks map: TaskIdentifier -> TrackId
    private var taskToTrackMap: [Int: String] = [:]
    private var downloadSession: URLSession!
    
    private override init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.offlineDir = docs.appendingPathComponent("OfflineAudio", isDirectory: true)
        self.metadataFile = self.offlineDir.appendingPathComponent("metadata.json")
        
        let savedQuota = UserDefaults.standard.double(forKey: "downtify_storage_quota_gb")
        self.storageQuotaGB = savedQuota > 0 ? savedQuota : 10.0 // Default 10GB limit
        
        super.init()
        
        // Ensure offline directory exists
        try? FileManager.default.createDirectory(at: offlineDir, withIntermediateDirectories: true)
        
        // Setup background download session configuration
        let config = URLSessionConfiguration.background(withIdentifier: "com.downtify.ios.offline.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        self.downloadSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        loadMetadata()
        recalculateStorage()
    }
    
    // MARK: - Local Querying
    
    public func isDownloaded(trackId: String) -> Bool {
        downloadedTrackIds.contains(trackId)
    }
    
    public func isDownloading(trackId: String) -> Bool {
        if let state = activeDownloads[trackId]?.state {
            return state == .downloading || state == .queued
        }
        return false
    }
    
    public func progress(for trackId: String) -> Double {
        activeDownloads[trackId]?.progress ?? (isDownloaded(trackId: trackId) ? 1.0 : 0.0)
    }
    
    /// Returns local file URL if file exists and is healthy; otherwise nil.
    public func localAudioUrl(for trackId: String) -> URL? {
        guard let info = metadataRegistry[trackId] else { return nil }
        let fileUrl = offlineDir.appendingPathComponent(info.fileName)
        if FileManager.default.fileExists(atPath: fileUrl.path) {
            return fileUrl
        }
        return nil
    }
    
    /// Returns local cover artwork URL if available.
    public func localCoverUrl(for trackId: String) -> URL? {
        let coverUrl = offlineDir.appendingPathComponent("\(trackId).artwork")
        if FileManager.default.fileExists(atPath: coverUrl.path) {
            return coverUrl
        }
        return nil
    }
    
    // MARK: - Download Operations
    
    public func downloadTrack(track: Track) {
        guard !isDownloaded(trackId: track.id) && !isDownloading(trackId: track.id) else { return }
        
        // Storage quota guard
        let quotaBytes = Int64(storageQuotaGB * 1024 * 1024 * 1024)
        if storageQuotaGB > 0 && totalAudioBytes + track.size > quotaBytes {
            print("[Offline] Storage quota exceeded. Cannot download track \(track.title)")
            return
        }
        
        guard let streamUrl = DowntifyAPI.shared.streamUrl(trackId: track.id),
              let token = KeychainSessionStore.shared.session?.token else { return }
        
        var request = URLRequest(url: streamUrl)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let task = downloadSession.downloadTask(with: request)
        taskToTrackMap[task.taskIdentifier] = track.id
        
        let ext = (track.file as NSString).pathExtension.lowercased()
        let cleanExt = ext.isEmpty ? "audio" : ext
        let localFileName = "\(track.id).\(cleanExt)"
        
        let info = OfflineTrackInfo(
            trackId: track.id,
            title: track.displayTitle,
            artist: track.displayArtist,
            album: track.album,
            albumId: track.albumId,
            duration: track.duration,
            fileName: localFileName,
            fileSize: track.size,
            downloadedAt: Date(),
            codec: track.codec
        )
        metadataRegistry[track.id] = info
        
        activeDownloads[track.id] = DownloadProgress(progress: 0, bytesWritten: 0, totalBytes: track.size, state: .queued)
        task.resume()
        
        // Also download cover art if available
        downloadCoverArtwork(for: track)
    }
    
    public func downloadAlbum(album: Album) {
        for track in album.tracks {
            downloadTrack(track: track)
        }
    }
    
    public func downloadPlaylist(tracks: [Track]) {
        for track in tracks {
            downloadTrack(track: track)
        }
    }
    
    private func downloadCoverArtwork(for track: Track) {
        guard track.hasCover, let url = DowntifyAPI.shared.coverUrl(trackId: track.id, size: 400) else { return }
        let coverFile = offlineDir.appendingPathComponent("\(track.id).artwork")
        if FileManager.default.fileExists(atPath: coverFile.path) { return }
        
        let token = KeychainSessionStore.shared.session?.token
        Task.detached(priority: .background) {
            var req = URLRequest(url: url)
            if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
            if let (data, _) = try? await URLSession.shared.data(for: req) {
                try? data.write(to: coverFile)
            }
        }
    }
    
    // MARK: - Removal & Deletion
    
    public func removeDownload(trackId: String) {
        if let info = metadataRegistry[trackId] {
            let fileUrl = offlineDir.appendingPathComponent(info.fileName)
            try? FileManager.default.removeItem(at: fileUrl)
            
            let coverUrl = offlineDir.appendingPathComponent("\(trackId).artwork")
            try? FileManager.default.removeItem(at: coverUrl)
            
            metadataRegistry.removeValue(forKey: trackId)
            downloadedTrackIds.remove(trackId)
            activeDownloads.removeValue(forKey: trackId)
            saveMetadata()
            recalculateStorage()
        }
    }
    
    public func removeAlbumDownloads(album: Album) {
        for track in album.tracks {
            removeDownload(trackId: track.id)
        }
    }
    
    public func removePlaylistDownloads(tracks: [Track]) {
        for track in tracks {
            removeDownload(trackId: track.id)
        }
    }
    
    public func clearAllDownloads() {
        try? FileManager.default.removeItem(at: offlineDir)
        try? FileManager.default.createDirectory(at: offlineDir, withIntermediateDirectories: true)
        metadataRegistry.removeAll()
        downloadedTrackIds.removeAll()
        activeDownloads.removeAll()
        saveMetadata()
        recalculateStorage()
    }
    
    public func clearArtworkCache() {
        // Clear in-memory & URLCache
        URLCache.shared.removeAllCachedResponses()
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    // MARK: - Storage Metadata Management
    
    private func loadMetadata() {
        guard let data = try? Data(contentsOf: metadataFile),
              let list = try? JSONDecoder().decode([OfflineTrackInfo].self, from: data) else { return }
        
        for item in list {
            let fileUrl = offlineDir.appendingPathComponent(item.fileName)
            if FileManager.default.fileExists(atPath: fileUrl.path) {
                metadataRegistry[item.trackId] = item
                downloadedTrackIds.insert(item.trackId)
            }
        }
    }
    
    private func saveMetadata() {
        let list = Array(metadataRegistry.values)
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: metadataFile, options: .atomic)
        }
    }
    
    public func recalculateStorage() {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: offlineDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            totalAudioBytes = 0
            return
        }
        var total: Int64 = 0
        for url in contents {
            if let res = try? url.resourceValues(forKeys: [.fileSizeKey]), let size = res.fileSize {
                total += Int64(size)
            }
        }
        self.totalAudioBytes = total
    }
    
    public func systemFreeStorageBytes() -> Int64 {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        if let values = try? docs.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let free = values.volumeAvailableCapacityForImportantUsage {
            return free
        }
        return 0
    }
    
    public func totalCacheBytes() -> Int64 {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        guard let contents = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return Int64(URLCache.shared.currentDiskUsage)
        }
        var total: Int64 = 0
        for url in contents {
            if let res = try? url.resourceValues(forKeys: [.fileSizeKey]), let size = res.fileSize {
                total += Int64(size)
            }
        }
        return total + Int64(URLCache.shared.currentDiskUsage)
    }
}

// MARK: - URLSessionDownloadDelegate

extension OfflineDownloadManager: URLSessionDownloadDelegate {
    public nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let taskId = downloadTask.taskIdentifier
        Task { @MainActor in
            guard let trackId = self.taskToTrackMap[taskId],
                  let info = self.metadataRegistry[trackId] else { return }
            
            let destUrl = self.offlineDir.appendingPathComponent(info.fileName)
            try? FileManager.default.removeItem(at: destUrl)
            do {
                try FileManager.default.moveItem(at: location, to: destUrl)
                self.downloadedTrackIds.insert(trackId)
                self.activeDownloads[trackId] = DownloadProgress(progress: 1.0, state: .completed)
                self.saveMetadata()
                self.recalculateStorage()
                print("[Offline] Successfully downloaded track: \(info.title)")
            } catch {
                self.activeDownloads[trackId] = DownloadProgress(progress: 0, state: .failed(error.localizedDescription))
                print("[Offline] Failed to move downloaded file: \(error)")
            }
            self.taskToTrackMap.removeValue(forKey: taskId)
        }
    }
    
    public nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let taskId = downloadTask.taskIdentifier
        let fraction = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        
        Task { @MainActor in
            guard let trackId = self.taskToTrackMap[taskId] else { return }
            self.activeDownloads[trackId] = DownloadProgress(
                progress: fraction,
                bytesWritten: totalBytesWritten,
                totalBytes: totalBytesExpectedToWrite,
                state: .downloading
            )
        }
    }
    
    public nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let taskId = task.taskIdentifier
        if let error = error {
            Task { @MainActor in
                guard let trackId = self.taskToTrackMap[taskId] else { return }
                self.activeDownloads[trackId] = DownloadProgress(progress: 0, state: .failed(error.localizedDescription))
                self.taskToTrackMap.removeValue(forKey: taskId)
                print("[Offline] Download failed for track \(trackId): \(error)")
            }
        }
    }
}
