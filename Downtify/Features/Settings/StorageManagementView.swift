import SwiftUI

/// Comprehensive storage management screen for Downtify offline audio, cover cache, and storage quotas.
public struct StorageManagementView: View {
    @ObservedObject private var downloadManager = OfflineDownloadManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showClearDownloadsAlert = false
    @State private var showClearCacheAlert = false
    
    let quotaOptions: [(label: String, value: Double)] = [
        ("Unlimited", 0.0),
        ("1 GB", 1.0),
        ("2 GB", 2.0),
        ("5 GB", 5.0),
        ("10 GB", 10.0),
        ("20 GB", 20.0),
        ("50 GB", 50.0)
    ]
    
    public init() {}
    
    private var audioBytes: Int64 {
        downloadManager.totalAudioBytes
    }
    
    private var cacheBytes: Int64 {
        downloadManager.totalCacheBytes()
    }
    
    private var freeBytes: Int64 {
        downloadManager.systemFreeStorageBytes()
    }
    
    public var body: some View {
        List {
            // MARK: - Visual Storage Breakdown
            Section("Storage Breakdown") {
                VStack(alignment: .leading, spacing: 14) {
                    // Breakdown Bar
                    GeometryReader { geo in
                        let total = max(Double(audioBytes + cacheBytes + (freeBytes > 0 ? freeBytes : 10_000_000_000)), 1.0)
                        let audioWidth = geo.size.width * CGFloat(Double(audioBytes) / total)
                        let cacheWidth = geo.size.width * CGFloat(Double(cacheBytes) / total)
                        
                        HStack(spacing: 2) {
                            Rectangle()
                                .fill(DowntifyColor.primary)
                                .frame(width: max(audioWidth, audioBytes > 0 ? 6 : 0))
                            
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: max(cacheWidth, cacheBytes > 0 ? 6 : 0))
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.15))
                        }
                        .cornerRadius(6)
                    }
                    .frame(height: 14)
                    
                    // Legend
                    HStack(spacing: 16) {
                        legendItem(color: DowntifyColor.primary, title: "Audio", size: formatBytes(audioBytes))
                        legendItem(color: Color.blue, title: "Cache", size: formatBytes(cacheBytes))
                        legendItem(color: Color.white.opacity(0.4), title: "Free", size: formatBytes(freeBytes))
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(DowntifyColor.surfaceRaised)
            }
            
            // MARK: - Quota Setting
            Section {
                Picker("Maximum Offline Storage", selection: $downloadManager.storageQuotaGB) {
                    ForEach(quotaOptions, id: \.value) { opt in
                        Text(opt.label).tag(opt.value)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Storage Limit")
            } footer: {
                Text("When the offline storage quota is reached, Downtify stops downloading additional tracks to protect your device storage.")
            }
            .listRowBackground(DowntifyColor.surface)
            
            // MARK: - Actions
            Section("Maintenance") {
                Button {
                    showClearCacheAlert = true
                } label: {
                    HStack {
                        Text("Clear Artwork & Temporary Cache")
                            .foregroundColor(DowntifyColor.textPrimary)
                        Spacer()
                        Text(formatBytes(cacheBytes))
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                }
                
                Button(role: .destructive) {
                    showClearDownloadsAlert = true
                } label: {
                    HStack {
                        Text("Remove All Downloaded Tracks")
                        Spacer()
                        Text("\(downloadManager.downloadedTrackIds.count) songs (\(formatBytes(audioBytes)))")
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                }
            }
            .listRowBackground(DowntifyColor.surface)
            
            // MARK: - Summary Statistics
            Section("Downloaded Tracks") {
                HStack {
                    Text("Total Offline Tracks")
                    Spacer()
                    Text("\(downloadManager.downloadedTrackIds.count)")
                        .foregroundColor(DowntifyColor.textSecondary)
                }
                HStack {
                    Text("Total Disk Space Used")
                    Spacer()
                    Text(formatBytes(audioBytes))
                        .foregroundColor(DowntifyColor.textSecondary)
                }
            }
            .listRowBackground(DowntifyColor.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DowntifyColor.backgroundDark.ignoresSafeArea())
        .navigationTitle("Storage Management")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Clear Artwork Cache",
            isPresented: $showClearCacheAlert,
            titleVisibility: .visible
        ) {
            Button("Clear Cache", role: .destructive) {
                downloadManager.clearArtworkCache()
                downloadManager.recalculateStorage()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clear \(formatBytes(cacheBytes)) of cached artwork and temporary files? Images will be re-downloaded as needed.")
        }
        .confirmationDialog(
            "Remove All Downloads",
            isPresented: $showClearDownloadsAlert,
            titleVisibility: .visible
        ) {
            Button("Delete All Downloads", role: .destructive) {
                downloadManager.clearAllDownloads()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete all \(downloadManager.downloadedTrackIds.count) downloaded tracks (\(formatBytes(audioBytes))) from your device?")
        }
    }
    
    private func legendItem(color: Color, title: String, size: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(DowntifyFont.caption.bold())
                    .foregroundColor(DowntifyColor.textPrimary)
                Text(size)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(DowntifyColor.textSecondary)
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 MB" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
