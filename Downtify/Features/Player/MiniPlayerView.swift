import SwiftUI

/// Docked Mini Player bar that floats right above the bottom TabBar.
/// Displays artwork, marquee title, artist, transport buttons, and progress line.
/// Tapping or swiping up expands into the full-screen NowPlayingView.
public struct MiniPlayerView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    public let onExpand: () -> Void
    
    @State private var isPlayBouncing = false
    
    public init(onExpand: @escaping () -> Void) {
        self.onExpand = onExpand
    }
    
    public var body: some View {
        if let track = player.currentTrack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Album Artwork
                    let coverUrl = track.hasCover ? DowntifyAPI.shared.coverUrl(trackId: track.id, size: 120) : nil
                    AuthenticatedArtworkImage(
                        url: coverUrl,
                        size: 46,
                        cornerRadius: 8
                    )
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                    
                    // Track Information (Title with Marquee + Artist)
                    VStack(alignment: .leading, spacing: 2) {
                        MarqueeText(
                            text: track.displayTitle,
                            font: DowntifyFont.cardTitle,
                            color: DowntifyColor.textPrimary
                        )
                        
                        Text(track.displayArtist)
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 8)
                    
                    // Previous Track Button
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        player.skipToPrevious()
                    } label: {
                        Image(systemName: DowntifyIcons.backward)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(DowntifyColor.textSecondary)
                            .frame(width: 32, height: 32)
                    }
                    
                    // Play / Pause Button with bounce animation
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                            isPlayBouncing = true
                        }
                        player.togglePlayPause()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            isPlayBouncing = false
                        }
                    } label: {
                        Group {
                            if player.state == .loading {
                                ProgressView()
                                    .tint(DowntifyColor.textPrimary)
                            } else {
                                Image(systemName: player.state == .playing ? DowntifyIcons.pause : DowntifyIcons.play)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(DowntifyColor.textPrimary)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .scaleEffect(isPlayBouncing ? 0.82 : 1.0)
                    }
                    
                    // Next Track Button
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        player.skipToNext()
                    } label: {
                        Image(systemName: DowntifyIcons.forward)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(DowntifyColor.textSecondary)
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: DowntifyShape.miniPlayerRadius, style: .continuous)
                        .fill(DowntifyColor.surfaceRaised)
                        .shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 4)
                )
                // Thin progress track along the bottom edge
                .overlay(alignment: .bottom) {
                    if player.duration > 0 {
                        GeometryReader { geo in
                            let progress = min(max(player.currentTime / player.duration, 0), 1)
                            Rectangle()
                                .fill(DowntifyColor.primary)
                                .frame(width: geo.size.width * CGFloat(progress), height: 2.5)
                        }
                        .frame(height: 2.5)
                        .clipShape(
                            RoundedRectangle(cornerRadius: DowntifyShape.miniPlayerRadius, style: .continuous)
                        )
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onExpand()
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.height < -25 {
                            onExpand()
                        }
                    }
            )
        }
    }
}
