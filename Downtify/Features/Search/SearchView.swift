import SwiftUI

public struct SearchView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var query = ""
    
    let categories: [(String, Color)] = [
        ("Playlists", .purple),
        ("New Releases", .pink),
        ("Podcasts", .orange),
        ("Rock", .red),
        ("Hip-Hop", .yellow),
        ("Indie", .blue),
        ("Electronic", .mint),
        ("Jazz", .brown),
        ("Classical", .teal),
        ("Discover", .indigo)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: DowntifyIcons.search)
                            .foregroundColor(DowntifyColor.textSecondary)
                        
                        TextField("What do you want to play?", text: $query)
                            .font(DowntifyFont.body)
                            .foregroundColor(DowntifyColor.textPrimary)
                        
                        if !query.isEmpty {
                            Button(action: { query = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(DowntifyColor.textSecondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: DowntifyShape.cardRadius, style: .continuous)
                            .fill(DowntifyColor.surfaceRaised)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    Text("Browse All")
                        .font(DowntifyFont.sectionTitle)
                        .foregroundColor(DowntifyColor.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    
                    // Category Grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(categories, id: \.0) { cat in
                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: DowntifyShape.coverRadius, style: .continuous)
                                    .fill(cat.1.gradient)
                                    .frame(height: 96)
                                
                                Text(cat.0)
                                    .font(DowntifyFont.sectionTitle)
                                    .foregroundColor(.white)
                                    .padding(12)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer(minLength: 80)
                }
            }
            .background(theme.currentBackground.ignoresSafeArea())
            .navigationTitle("Search")
        }
    }
}
