import SwiftUI

public struct HomeView: View {
    @ObservedObject var theme = ThemeManager.shared
    
    let mockAlbums: [(String, String, [Color])] = [
        ("Discover Weekly", "Made for you", [.blue, .purple]),
        ("Heavy Rotation", "Your top tracks", [.red, .orange]),
        ("Chill Vibes", "Downtempo & beats", [.teal, .mint]),
        ("Indie Anthems", "New releases", [.indigo, .pink]),
        ("Late Night Jazz", "Smooth classics", [.brown, .yellow])
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Greeting
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome to Downtify")
                                .font(DowntifyFont.hero)
                                .foregroundColor(DowntifyColor.textPrimary)
                            Text("Ready to stream from your music server")
                                .font(DowntifyFont.body)
                                .foregroundColor(DowntifyColor.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // Quick Picks 2-column Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(mockAlbums.prefix(4), id: \.0) { album in
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(LinearGradient(colors: album.2, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .foregroundColor(.white.opacity(0.8))
                                    )
                                
                                Text(album.0)
                                    .font(DowntifyFont.cardTitle)
                                    .foregroundColor(DowntifyColor.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer(minLength: 0)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(DowntifyColor.surfaceRaised)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Recently Played Horizontal Carousel
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Recently Played", actionTitle: "See all")
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(mockAlbums, id: \.0) { item in
                                    ArtworkCard(
                                        title: item.0,
                                        subtitle: item.1,
                                        gradientColors: item.2,
                                        size: 140
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Made For You Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Made For You")
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(mockAlbums.reversed(), id: \.0) { item in
                                    ArtworkCard(
                                        title: item.0,
                                        subtitle: item.1,
                                        gradientColors: item.2,
                                        size: 140
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Bottom padding for mini-player
                    Spacer(minLength: 80)
                }
            }
            .background(theme.currentBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
