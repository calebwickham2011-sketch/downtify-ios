import SwiftUI

/// Synced karaoke-style lyrics screen matching Downtify Android's `LyricsScreen.kt`.
/// Features real-time line highlighting with spring animations, auto-scrolling to active line,
/// tap-to-seek, lyrics timing offset calibration, and transport controls.
public struct LyricsView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var lyrics: Lyrics = .empty
    @State private var isLoading: Bool = true
    @State private var timingOffsetMs: Int64 = 0
    @State private var showTimingAdjuster: Bool = false
    @State private var userIsScrolling: Bool = false
    @State private var scrollResumeTask: Task<Void, Never>? = nil
    
    public init() {}
    
    private var effectivePositionMs: Int64 {
        Int64(player.currentTime * 1000.0)
    }
    
    private var displayedLines: [LyricLine] {
        LyricsTiming.shift(lines: lyrics.synced, offsetMs: timingOffsetMs)
    }
    
    private var activeLineIndex: Int {
        LrcParser.activeIndex(lines: displayedLines, positionMs: effectivePositionMs)
    }
    
    public var body: some View {
        ZStack {
            // Solid dark background
            DowntifyColor.backgroundDark
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Header
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                
                // Timing Offset Pill (if adjusted)
                if showTimingAdjuster || timingOffsetMs != 0 {
                    timingBar
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Lyrics Content
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(DowntifyColor.primary)
                    Text("Loading lyrics…")
                        .font(DowntifyFont.caption)
                        .foregroundColor(DowntifyColor.textSecondary)
                        .padding(.top, 8)
                    Spacer()
                } else if lyrics.isSynced {
                    syncedLyricsList
                } else if !lyrics.text.isEmpty {
                    plainLyricsView
                } else {
                    noLyricsView
                }
                
                // Bottom floating transport bar
                bottomTransportBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadLyrics()
        }
        .onChange(of: player.currentTrack?.id) { _, _ in
            loadLyrics()
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(DowntifyColor.textPrimary)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(player.currentTrack?.displayTitle ?? "Lyrics")
                    .font(DowntifyFont.cardTitle)
                    .foregroundColor(DowntifyColor.textPrimary)
                    .lineLimit(1)
                
                Text(player.currentTrack?.displayArtist ?? "")
                    .font(DowntifyFont.caption)
                    .foregroundColor(DowntifyColor.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Timing adjustment toggle button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showTimingAdjuster.toggle()
                }
            } label: {
                Image(systemName: "timer")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(timingOffsetMs != 0 ? DowntifyColor.primary : DowntifyColor.textSecondary)
                    .frame(width: 44, height: 44)
            }
        }
    }
    
    // MARK: - Timing Adjuster Bar
    private var timingBar: some View {
        HStack(spacing: 12) {
            Text("Timing Offset:")
                .font(DowntifyFont.caption)
                .foregroundColor(DowntifyColor.textSecondary)
            
            Button {
                timingOffsetMs = LyricsTiming.clamp(offsetMs: timingOffsetMs - LyricsTiming.stepMs)
            } label: {
                Text("-0.25s")
                    .font(DowntifyFont.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DowntifyColor.surfaceRaised)
                    .cornerRadius(6)
            }
            
            Text("\(LyricsTiming.seconds(offsetMs: timingOffsetMs))s")
                .font(DowntifyFont.caption.monospacedDigit().bold())
                .foregroundColor(timingOffsetMs != 0 ? DowntifyColor.primary : DowntifyColor.textPrimary)
                .frame(minWidth: 50)
            
            Button {
                timingOffsetMs = LyricsTiming.clamp(offsetMs: timingOffsetMs + LyricsTiming.stepMs)
            } label: {
                Text("+0.25s")
                    .font(DowntifyFont.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DowntifyColor.surfaceRaised)
                    .cornerRadius(6)
            }
            
            if timingOffsetMs != 0 {
                Button {
                    timingOffsetMs = 0
                } label: {
                    Text("Reset")
                        .font(DowntifyFont.caption)
                        .foregroundColor(DowntifyColor.error)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(DowntifyColor.surfaceHighlight.opacity(0.8))
        .cornerRadius(12)
    }
    
    // MARK: - Synced Lyrics List
    private var syncedLyricsList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    // Top spacing
                    Color.clear.frame(height: 60)
                    
                    ForEach(Array(displayedLines.enumerated()), id: \.element.id) { index, line in
                        let isActive = (index == activeLineIndex)
                        let isPast = (index < activeLineIndex)
                        
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            let seekSeconds = Double(line.timeMs) / 1000.0
                            player.seek(to: seekSeconds)
                        } label: {
                            Text(line.text.isEmpty ? "•••" : line.text)
                                .font(.system(
                                    size: isActive ? 26 : 21,
                                    weight: isActive ? .heavy : .semibold,
                                    design: .rounded
                                ))
                                .foregroundColor(
                                    isActive
                                        ? Color.white
                                        : (isPast ? Color.white.opacity(0.38) : Color.white.opacity(0.50))
                                )
                                .scaleEffect(isActive ? 1.03 : 1.0, anchor: .leading)
                                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isActive)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(line.id)
                    }
                    
                    // Bottom spacing
                    Color.clear.frame(height: 120)
                }
                .padding(.horizontal, 28)
            }
            .onChange(of: activeLineIndex) { _, newIndex in
                guard !userIsScrolling, displayedLines.indices.contains(newIndex) else { return }
                let activeId = displayedLines[newIndex].id
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    proxy.scrollTo(activeId, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Plain Lyrics View
    private var plainLyricsView: some View {
        ScrollView {
            Text(lyrics.text)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundColor(DowntifyColor.textPrimary)
                .lineSpacing(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.vertical, 32)
        }
    }
    
    // MARK: - No Lyrics View
    private var noLyricsView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "quote.bubble")
                .font(.system(size: 48))
                .foregroundColor(DowntifyColor.textTertiary)
            Text("No Lyrics Available")
                .font(DowntifyFont.sectionTitle)
                .foregroundColor(DowntifyColor.textPrimary)
            Text("Lyrics haven't been synchronized for this track yet.")
                .font(DowntifyFont.caption)
                .foregroundColor(DowntifyColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
    
    // MARK: - Bottom Transport Bar
    private var bottomTransportBar: some View {
        HStack(spacing: 16) {
            // Seek scrubber info
            VStack(alignment: .leading, spacing: 2) {
                Text(formatTime(player.currentTime))
                    .font(DowntifyFont.caption.monospacedDigit())
                    .foregroundColor(DowntifyColor.textSecondary)
                
                GeometryReader { geo in
                    let progress = player.duration > 0 ? min(max(player.currentTime / player.duration, 0), 1) : 0
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                        Capsule()
                            .fill(DowntifyColor.primary)
                            .frame(width: geo.size.width * CGFloat(progress))
                    }
                }
                .frame(height: 4)
            }
            
            // Play / Pause Circle
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 48, height: 48)
                        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
                    
                    Image(systemName: player.state == .playing ? DowntifyIcons.pause : DowntifyIcons.play)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .offset(x: player.state == .playing ? 0 : 1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DowntifyColor.surfaceRaised)
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 3)
        )
    }
    
    // MARK: - Data Loading
    private func loadLyrics() {
        guard let track = player.currentTrack else {
            lyrics = .empty
            isLoading = false
            return
        }
        isLoading = true
        timingOffsetMs = 0
        
        Task {
            do {
                let result = try await DowntifyAPI.shared.fetchLyrics(trackId: track.id)
                await MainActor.run {
                    self.lyrics = result
                    self.isLoading = false
                }
            } catch {
                // If the track does not have server lyrics, provide graceful fallback
                await MainActor.run {
                    self.lyrics = .empty
                    self.isLoading = false
                }
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
