import SwiftUI

public class ArtworkCache {
    public static let shared = ArtworkCache()
    private let cache = NSCache<NSURL, UIImage>()
    
    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }
    
    public func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }
    
    public func set(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

public struct AuthenticatedArtworkImage: View {
    public let url: URL?
    public let size: CGFloat
    public let cornerRadius: CGFloat
    
    @State private var uiImage: UIImage?
    @State private var isLoading = false
    
    public init(url: URL?, size: CGFloat, cornerRadius: CGFloat = 12) {
        self.url = url
        self.size = size
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        ZStack {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                // Placeholder gradient
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.35))
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear {
            loadImage()
        }
        .onChange(of: url) { _, _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        if let cached = ArtworkCache.shared.image(for: url) {
            self.uiImage = cached
            return
        }
        guard !isLoading else { return }
        isLoading = true
        
        let token = KeychainSessionStore.shared.session?.token
        var request = URLRequest(url: url)
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      let image = UIImage(data: data) else {
                    await MainActor.run { isLoading = false }
                    return
                }
                ArtworkCache.shared.set(image, for: url)
                await MainActor.run {
                    self.uiImage = image
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}
