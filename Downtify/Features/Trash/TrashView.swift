import SwiftUI

public struct TrashView: View {
    @ObservedObject var theme = ThemeManager.shared
    
    @State private var capability = TrashCapability()
    @State private var trashPage = TrashPage()
    @State private var searchQuery = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var restoringIds = Set<String>()
    @State private var statusMessage: String?
    
    public init() {}
    
    private var filteredItems: [TrashItem] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return trashPage.items
        }
        return trashPage.items.filter {
            TextSearch.matches(query: searchQuery, fields: [$0.displayTitle, $0.artist, $0.file])
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header stats banner
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(trashPage.total) items in Trash")
                            .font(DowntifyFont.bodyBold)
                            .foregroundColor(DowntifyColor.textPrimary)
                        
                        let formattedSize = ByteCountFormatter.string(fromByteCount: trashPage.bytes, countStyle: .file)
                        Text("\(formattedSize) • Retention: \(capability.retentionDays) days")
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                    
                    Spacer()
                    
                    if !trashPage.items.isEmpty {
                        Button("Restore All") {
                            restoreAll()
                        }
                        .font(DowntifyFont.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(DowntifyColor.surfaceRaised)
                        .foregroundColor(DowntifyColor.primary)
                        .cornerRadius(12)
                    }
                }
                
                // Search bar within trash
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DowntifyColor.textSecondary)
                    TextField("Filter trashed files...", text: $searchQuery)
                        .font(DowntifyFont.caption)
                        .foregroundColor(DowntifyColor.textPrimary)
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DowntifyColor.textSecondary)
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(DowntifyColor.surface)
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DowntifyColor.surfaceRaised.opacity(0.5))
            
            if let status = statusMessage {
                HStack {
                    Text(status)
                        .font(DowntifyFont.caption)
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
            }
            
            // Content List
            if isLoading && trashPage.items.isEmpty {
                VStack(spacing: 16) {
                    ProgressView().tint(DowntifyColor.primary)
                    Text("Loading trash...")
                        .font(DowntifyFont.caption)
                        .foregroundColor(DowntifyColor.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trash.slash")
                        .font(.system(size: 48))
                        .foregroundColor(DowntifyColor.textSecondary)
                    Text(searchQuery.isEmpty ? "Trash is Empty" : "No matching items")
                        .font(DowntifyFont.sectionTitle)
                        .foregroundColor(DowntifyColor.textPrimary)
                    Text(searchQuery.isEmpty ? "Deleted tracks appear here before being permanently purged." : "Try adjusting your search query.")
                        .font(DowntifyFont.caption)
                        .foregroundColor(DowntifyColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredItems) { item in
                        TrashItemRow(
                            item: item,
                            isRestoring: restoringIds.contains(item.id),
                            onRestore: { restoreItem(item) },
                            onRetry: { retryItem(item) }
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(theme.currentBackground.ignoresSafeArea())
        .navigationTitle("Music Trash")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadTrash()
        }
        .task {
            await loadTrash()
        }
    }
    
    private func loadTrash() async {
        isLoading = true
        errorMessage = nil
        do {
            async let capCall = DowntifyAPI.shared.fetchTrashCapabilities()
            async let listCall = DowntifyAPI.shared.fetchTrashList(offset: 0, limit: 100, search: "")
            let (cap, list) = try await (capCall, listCall)
            self.capability = cap
            self.trashPage = list
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func restoreItem(_ item: TrashItem) {
        restoringIds.insert(item.id)
        Task {
            do {
                try await DowntifyAPI.shared.restoreTrashItems(ids: [item.id])
                statusMessage = "Restored '\(item.displayTitle)'"
                await loadTrash()
            } catch {
                errorMessage = "Failed to restore: \(error.localizedDescription)"
            }
            restoringIds.remove(item.id)
        }
    }
    
    private func retryItem(_ item: TrashItem) {
        Task {
            do {
                try await DowntifyAPI.shared.retryTrashItems(ids: [item.id])
                statusMessage = "Retried action for '\(item.displayTitle)'"
                await loadTrash()
            } catch {
                errorMessage = "Retry failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func restoreAll() {
        let allIds = trashPage.items.filter { $0.isRestorable }.map { $0.id }
        guard !allIds.isEmpty else { return }
        Task {
            do {
                try await DowntifyAPI.shared.restoreTrashItems(ids: allIds)
                statusMessage = "Restoring \(allIds.count) items..."
                await loadTrash()
            } catch {
                errorMessage = "Failed to restore: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Trash Item Row

struct TrashItemRow: View {
    let item: TrashItem
    let isRestoring: Bool
    let onRestore: () -> Void
    let onRetry: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DowntifyColor.surfaceRaised)
                    .frame(width: 44, height: 44)
                
                Image(systemName: "music.note")
                    .foregroundColor(DowntifyColor.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayTitle)
                    .font(DowntifyFont.bodyBold)
                    .foregroundColor(DowntifyColor.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if !item.artist.isEmpty {
                        Text(item.artist)
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                            .lineLimit(1)
                        Text("•")
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                    
                    Text(item.format)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(DowntifyColor.surfaceRaised)
                        .foregroundColor(DowntifyColor.primary)
                        .cornerRadius(4)
                    
                    Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                        .font(DowntifyFont.caption)
                        .foregroundColor(DowntifyColor.textTertiary)
                }
                
                if let expiry = item.expiresAt {
                    Text("Expires \(expiry, style: .relative)")
                        .font(.system(size: 11))
                        .foregroundColor(.orange.opacity(0.8))
                }
            }
            
            Spacer()
            
            if isRestoring {
                ProgressView().tint(DowntifyColor.primary)
            } else if item.state == .error {
                Button("Retry", action: onRetry)
                    .font(DowntifyFont.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)
            } else if item.isRestorable {
                Button("Restore", action: onRestore)
                    .font(DowntifyFont.caption)
                    .foregroundColor(DowntifyColor.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DowntifyColor.primary.opacity(0.15))
                    .cornerRadius(8)
            } else {
                Text(item.state.label)
                    .font(.system(size: 11))
                    .foregroundColor(DowntifyColor.textTertiary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: DowntifyShape.cardRadius, style: .continuous)
                .fill(DowntifyColor.surface)
        )
    }
}
