import SwiftUI

public struct LibraryView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var selectedFilter = "All"
    let filters = ["All", "Playlists", "Albums", "Artists", "Downloaded"]
    
    let libraryItems: [(String, String, String, Color)] = [
        ("Liked Songs", "Playlist • 84 songs", DowntifyIcons.heartFill, DowntifyColor.liked),
        ("Daily Mix 1", "Playlist • Downtify", "music.note.list", .purple),
        ("Starred Albums", "Collection • 12 albums", "square.stack.fill", .blue),
        ("Offline Cache", "Downloaded • 35 tracks", DowntifyIcons.downloadDone, DowntifyColor.primary),
        ("Podcasts", "Shows • 4 subscriptions", "mic.fill", .orange)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { filter in
                            PillFilter(
                                title: filter,
                                isSelected: selectedFilter == filter,
                                action: { selectedFilter = filter }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                
                // Library List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(libraryItems, id: \.0) { item in
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: DowntifyShape.coverRadius, style: .continuous)
                                    .fill(item.3.gradient)
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Image(systemName: item.2)
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.0)
                                        .font(DowntifyFont.cardTitle)
                                        .foregroundColor(DowntifyColor.textPrimary)
                                    
                                    Text(item.1)
                                        .font(DowntifyFont.cardSubtitle)
                                        .foregroundColor(DowntifyColor.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(DowntifyColor.textTertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.top, 8)
                    
                    Spacer(minLength: 80)
                }
            }
            .background(theme.currentBackground.ignoresSafeArea())
            .navigationTitle("Your Library")
        }
    }
}
