import SwiftUI
import UIKit

/// Full-screen Now Playing screen matching Downtify Android's ExpandingPlayer / NowPlayingScreen.
/// Features dynamic ambient color extraction from cover art, wavy seek bar, squircle hero artwork,
/// bouncy transport controls, volume slider with loudness normalization, and interactive drag dismissal.
public struct NowPlayingView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var libraryRepo = LibraryRepository.shared
    public let onDismiss: () -> Void
    
    // Interactive dismissal drag state
    @State private var dragOffset: CGFloat = 0.0
    
    // Dynamic color extraction state
    @State private var primaryColor: Color = DowntifyColor.primary
    @State private var ambientBgColor: Color = DowntifyColor.backgroundDark
    
    // Bounce animations
    @State private var isPlayBouncing: Bool = false
    @State private var isLikeBouncing: Bool = false
    
    // Sheets
    @State private var showQueue: Bool = false
    @State private var showLyrics: Bool = false
    
    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    private var isCurrentTrackLiked: Bool {
        guard let track = player.currentTrack else { return false }
        return libraryRepo.likedTrackIds.contains(track.id)
    }
    
    public var body: some View {
        GeometryReader { geo in
            let screenHeight = geo.size.height
            let screenWidth = geo.size.width
            let artworkSize = min(screenWidth - 64, 340)
            
            ZStack {
                // Completely solid, opaque black base to ensure zero transparency
                Color.black
                    .ignoresSafeArea()
                
                // MARK: - Dynamic Ambient Gradient Background
                LinearGradient(
                    colors: [
                        ambientBgColor,
                        primaryColor.opacity(0.35),
                        DowntifyColor.backgroundDark
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: ambientBgColor)
                
                // Subtle radial light pool behind artwork
                RadialGradient(
                    colors: [primaryColor.opacity(0.40), Color.clear],
                    center: .top,
                    startRadius: 20,
                    endRadius: screenHeight * 0.55
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: primaryColor)
                
                // MARK: - Content Layout
                VStack(spacing: 0) {
                    // Top Navigation Header (lowered for Dynamic Island)
                    topHeader
                        .padding(.horizontal, 20)
                        .padding(.top, max(geo.safeAreaInsets.top, 54) + 6)
                    
                    Spacer(minLength: 8)
                    
                    // Hero Album Artwork
                    heroArtwork(size: artworkSize)
                        .padding(.horizontal, 32)
                    
                    Spacer(minLength: 16)
                    
                    // Track Title, Artist & Like Button
                    trackMetadataRow
                        .padding(.horizontal, 24)
                    
                    // Custom Wavy Seek Bar
                    WavySeekBar(
                        currentTime: player.currentTime,
                        duration: player.duration > 0 ? player.duration : (player.currentTrack?.duration ?? 0),
                        isPlaying: player.state == .playing,
                        onSeek: { target in
                            player.seek(to: target)
                        }
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Full Playback Transport Controls
                    playbackControlsRow
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    
                    // Volume Slider & Normalization Badge
                    volumeAndNormalizationRow
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                    
                    // Bottom Accessory Actions (Lyrics, Queue)
                    bottomAccessoriesRow
                        .padding(.horizontal, 28)
                        .padding(.top, 10)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .offset(y: max(0, dragOffset))
            .scaleEffect(dragOffset > 0 ? max(0.92, 1.0 - (dragOffset / screenHeight) * 0.15) : 1.0)
            .background(Color.black.ignoresSafeArea())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 120 || value.predictedEndTranslation.height > 300 {
                            withAnimation(.easeOut(duration: 0.22)) {
                                dragOffset = screenHeight
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                onDismiss()
                            }
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .sheet(isPresented: $showQueue) {
            UpNextQueueView()
        }
        .fullScreenCover(isPresented: $showLyrics) {
            LyricsView()
        }
        .onAppear {
            extractCoverColors()
        }
        .onChange(of: player.currentTrack?.id) { _, _ in
            extractCoverColors()
        }
    }
    
    // MARK: - Top Header
    private var topHeader: some View {
        HStack {
            // Collapse Chevron
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                onDismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(DowntifyColor.textPrimary)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            // Context description
            VStack(spacing: 2) {
                Text(playbackContextSubhead.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(DowntifyColor.textTertiary)
                    .tracking(1.0)
                
                Text(player.currentTrack?.album ?? "Downtify")
                    .font(DowntifyFont.cardSubtitle)
                    .foregroundColor(DowntifyColor.textPrimary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Queue button shortcut
            Button {
                showQueue = true
            } label: {
                Image(systemName: DowntifyIcons.queue)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(DowntifyColor.textSecondary)
                    .frame(width: 44, height: 44)
            }
        }
    }
    
    private var playbackContextSubhead: String {
        if !player.playbackContext.isEmpty {
            return player.playbackContext
        }
        if let current = player.currentTrack, !current.album.isEmpty {
            return "Playing from album"
        }
        return "Playing from library"
    }
    
    // MARK: - Hero Artwork
    private func heroArtwork(size: CGFloat) -> some View {
        let track = player.currentTrack
        let coverUrl = track?.hasCover == true && track != nil
            ? DowntifyAPI.shared.coverUrl(trackId: track!.id, size: 600)
            : nil
        
        return AuthenticatedArtworkImage(
            url: coverUrl,
            size: size,
            cornerRadius: DowntifyShape.heroRadius
        )
        .shadow(color: primaryColor.opacity(0.35), radius: 24, x: 0, y: 12)
        .shadow(color: .black.opacity(0.55), radius: 16, x: 0, y: 8)
    }
    
    // MARK: - Track Metadata Row
    private var trackMetadataRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                MarqueeText(
                    text: player.currentTrack?.displayTitle ?? "No Track",
                    font: .system(size: 22, weight: .bold, design: .rounded),
                    color: DowntifyColor.textPrimary
                )
                
                Text(player.currentTrack?.displayArtist ?? "")
                    .font(DowntifyFont.body)
                    .foregroundColor(DowntifyColor.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 12)
            
            // Like / Favorite Heart Button
            Button {
                guard let track = player.currentTrack else { return }
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    isLikeBouncing = true
                }
                Task {
                    await libraryRepo.toggleLike(trackId: track.id)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        isLikeBouncing = false
                    }
                }
            } label: {
                Image(systemName: isCurrentTrackLiked ? DowntifyIcons.heartFill : DowntifyIcons.heart)
                    .font(.system(size: 24))
                    .foregroundColor(isCurrentTrackLiked ? DowntifyColor.liked : DowntifyColor.textSecondary)
                    .scaleEffect(isLikeBouncing ? 1.35 : 1.0)
                    .frame(width: 44, height: 44)
            }
        }
    }
    
    // MARK: - Playback Controls Row
    private var playbackControlsRow: some View {
        HStack(alignment: .center) {
            // Shuffle
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.toggleShuffle()
            } label: {
                Image(systemName: DowntifyIcons.shuffle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(player.isShuffled ? DowntifyColor.primary : DowntifyColor.textSecondary)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            // Previous
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.skipToPrevious()
            } label: {
                Image(systemName: DowntifyIcons.backward)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(DowntifyColor.textPrimary)
                    .frame(width: 48, height: 48)
            }
            
            Spacer()
            
            // Play / Pause Circle
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                    isPlayBouncing = true
                }
                player.togglePlayPause()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    isPlayBouncing = false
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 68, height: 68)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    if player.state == .loading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: player.state == .playing ? DowntifyIcons.pause : DowntifyIcons.play)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                            .offset(x: player.state == .playing ? 0 : 2)
                    }
                }
                .scaleEffect(isPlayBouncing ? 0.88 : 1.0)
            }
            
            Spacer()
            
            // Next
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.skipToNext()
            } label: {
                Image(systemName: DowntifyIcons.forward)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(DowntifyColor.textPrimary)
                    .frame(width: 48, height: 48)
            }
            
            Spacer()
            
            // Repeat
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.toggleRepeat()
            } label: {
                Image(systemName: repeatIconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(player.repeatMode != .off ? DowntifyColor.primary : DowntifyColor.textSecondary)
                    .frame(width: 44, height: 44)
            }
        }
    }
    
    private var repeatIconName: String {
        switch player.repeatMode {
        case .off: return DowntifyIcons.repeatAll
        case .all: return DowntifyIcons.repeatAll
        case .one: return DowntifyIcons.repeatOne
        }
    }
    
    // MARK: - Volume & Normalization Row
    private var volumeAndNormalizationRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 13))
                    .foregroundColor(DowntifyColor.textTertiary)
                
                Slider(value: Binding(
                    get: { Double(player.volume) },
                    set: { player.setVolume(Float($0)) }
                ), in: 0...1)
                .tint(Color.white.opacity(0.85))
                
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 13))
                    .foregroundColor(DowntifyColor.textTertiary)
            }
            
            // Peak Loudness Normalization Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(DowntifyColor.primary)
                    .frame(width: 6, height: 6)
                
                Text("PEAK -1.2 dB · LOUDNESS NORMALIZATION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(DowntifyColor.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
            )
        }
    }
    
    // MARK: - Bottom Accessories Row
    private var bottomAccessoriesRow: some View {
        HStack {
            // Lyrics Button
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                showLyrics = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: DowntifyIcons.lyrics)
                        .font(.system(size: 16))
                    Text("Lyrics")
                        .font(DowntifyFont.caption)
                }
                .foregroundColor(DowntifyColor.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
            }
            
            Spacer()
            
            // Audio Stream Format Tag (e.g. 44.1 kHz · FLAC / AAC)
            if let track = player.currentTrack {
                Text(track.codec.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(DowntifyColor.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.08))
                    )
            }
            
            Spacer()
            
            // Queue Button
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                showQueue = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: DowntifyIcons.queue)
                        .font(.system(size: 16))
                    Text("Queue")
                        .font(DowntifyFont.caption)
                }
                .foregroundColor(DowntifyColor.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
            }
        }
    }
    
    // MARK: - Color Extraction
    private func extractCoverColors() {
        guard let track = player.currentTrack, track.hasCover,
              let url = DowntifyAPI.shared.coverUrl(trackId: track.id, size: 200) else {
            primaryColor = DowntifyColor.primary
            ambientBgColor = DowntifyColor.backgroundDark
            return
        }
        
        if let cachedImage = ArtworkCache.shared.image(for: url) {
            let extracted = DominantColorExtractor.shared.extractColors(from: cachedImage, key: track.id)
            self.primaryColor = extracted.primary
            self.ambientBgColor = extracted.background
        } else {
            let token = KeychainSessionStore.shared.session?.token
            Task.detached(priority: .background) {
                var request = URLRequest(url: url)
                if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
                if let (data, _) = try? await URLSession.shared.data(for: request),
                   let image = UIImage(data: data) {
                    ArtworkCache.shared.set(image, for: url)
                    let extracted = DominantColorExtractor.shared.extractColors(from: image, key: track.id)
                    await MainActor.run {
                        self.primaryColor = extracted.primary
                        self.ambientBgColor = extracted.background
                    }
                }
            }
        }
    }
}
