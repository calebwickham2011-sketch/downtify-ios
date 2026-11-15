import SwiftUI

/// A custom sine-wave seek bar matching Downtify Android's LinearWavyProgressIndicator / WavySeekBar.
/// When playing, the elapsed portion ripples with a subtle harmonic wave.
/// When paused or actively scrubbing, it flattens into a straight, precise line.
public struct WavySeekBar: View {
    public let currentTime: Double
    public let duration: Double
    public let isPlaying: Bool
    public let onSeek: (Double) -> Void
    
    @State private var isDragging: Bool = false
    @State private var dragProgress: Double = 0.0
    @State private var wavePhase: Double = 0.0
    
    public init(
        currentTime: Double,
        duration: Double,
        isPlaying: Bool,
        onSeek: @escaping (Double) -> Void
    ) {
        self.currentTime = currentTime
        self.duration = duration
        self.isPlaying = isPlaying
        self.onSeek = onSeek
    }
    
    private var effectiveProgress: Double {
        if isDragging {
            return dragProgress
        }
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }
    
    private var displayedElapsed: Double {
        if isDragging {
            return dragProgress * duration
        }
        return currentTime
    }
    
    private var displayedRemaining: Double {
        let current = displayedElapsed
        return max(duration - current, 0)
    }
    
    public var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let centerY = height / 2.0
                let activeWidth = width * CGFloat(effectiveProgress)
                let wavelength: CGFloat = 28.0
                let maxAmplitude: CGFloat = isPlaying && !isDragging ? 3.5 : 0.0
                
                ZStack(alignment: .leading) {
                    // Inactive track (straight line)
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 4)
                        .cornerRadius(2)
                        .position(x: width / 2.0, y: centerY)
                    
                    // Active track (wavy or straight line)
                    TimelineView(.animation(paused: !isPlaying || isDragging)) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        let phase = time * 3.5
                        
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: centerY))
                            
                            if maxAmplitude > 0 && activeWidth > 2 {
                                var x: CGFloat = 0
                                while x <= activeWidth {
                                    let relativeX = x / wavelength
                                    let y = centerY + sin(relativeX * 2 * .pi + phase) * maxAmplitude
                                    path.addLine(to: CGPoint(x: x, y: y))
                                    x += 2
                                }
                            } else {
                                path.addLine(to: CGPoint(x: activeWidth, y: centerY))
                            }
                        }
                        .stroke(
                            DowntifyColor.primary,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                    }
                    
                    // Scrubbing Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: isDragging ? 18 : 12, height: isDragging ? 18 : 12)
                        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                        .position(x: max(6, min(activeWidth, width - 6)), y: centerY)
                        .animation(.spring(response: 0.25), value: isDragging)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                            let progress = min(max(value.location.x / width, 0), 1)
                            dragProgress = progress
                        }
                        .onEnded { value in
                            let finalProgress = min(max(value.location.x / width, 0), 1)
                            isDragging = false
                            let seekTarget = finalProgress * duration
                            onSeek(seekTarget)
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }
                )
            }
            .frame(height: 28)
            
            // Timestamps
            HStack {
                Text(formatTime(displayedElapsed))
                    .font(DowntifyFont.caption.monospacedDigit())
                    .foregroundColor(DowntifyColor.textSecondary)
                
                Spacer()
                
                Text("-\(formatTime(displayedRemaining))")
                    .font(DowntifyFont.caption.monospacedDigit())
                    .foregroundColor(DowntifyColor.textTertiary)
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
