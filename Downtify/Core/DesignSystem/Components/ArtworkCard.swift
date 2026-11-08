import SwiftUI

public struct ArtworkCard: View {
    public let title: String
    public let subtitle: String
    public let gradientColors: [Color]
    public let size: CGFloat
    
    public init(
        title: String,
        subtitle: String,
        gradientColors: [Color] = [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
        size: CGFloat = 140
    ) {
        self.title = title
        self.subtitle = subtitle
        self.gradientColors = gradientColors
        self.size = size
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: DowntifyShape.coverRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.3))
                            .foregroundColor(.white.opacity(0.4))
                    )
                
                // Play overlay button
                Circle()
                    .fill(DowntifyColor.primary)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                    .overlay(
                        Image(systemName: DowntifyIcons.play)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .offset(x: 1)
                    )
                    .padding(8)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DowntifyFont.cardTitle)
                    .foregroundColor(DowntifyColor.textPrimary)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(DowntifyFont.cardSubtitle)
                    .foregroundColor(DowntifyColor.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: size, alignment: .leading)
        }
    }
}
