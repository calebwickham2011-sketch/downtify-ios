import SwiftUI

/// A text component that smoothly scrolls back and forth if its content overflows its container width.
public struct MarqueeText: View {
    public let text: String
    public let font: Font
    public let color: Color
    
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    
    public init(text: String, font: Font = DowntifyFont.cardTitle, color: Color = DowntifyColor.textPrimary) {
        self.text = text
        self.font = font
        self.color = color
    }
    
    public var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width
            ZStack(alignment: .leading) {
                Text(text)
                    .font(font)
                    .foregroundColor(color)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        GeometryReader { textGeo in
                            Color.clear
                                .onAppear {
                                    self.textWidth = textGeo.size.width
                                    self.containerWidth = availableWidth
                                    startAnimationIfNeeded()
                                }
                                .onChange(of: text) { _, _ in
                                    self.textWidth = textGeo.size.width
                                    self.containerWidth = availableWidth
                                    self.offset = 0
                                    startAnimationIfNeeded()
                                }
                        }
                    )
                    .offset(x: offset)
            }
            .frame(width: availableWidth, alignment: .leading)
            .clipped()
            .onChange(of: availableWidth) { _, newWidth in
                self.containerWidth = newWidth
                startAnimationIfNeeded()
            }
        }
        .frame(height: 24)
    }
    
    private func startAnimationIfNeeded() {
        guard textWidth > containerWidth && containerWidth > 0 else {
            withAnimation(.default) {
                offset = 0
            }
            return
        }
        
        let overflow = textWidth - containerWidth
        let duration = Double(overflow) / 25.0 + 2.0
        
        withAnimation(.linear(duration: 0.1)) {
            offset = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard self.textWidth > self.containerWidth else { return }
            withAnimation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true)
            ) {
                self.offset = -overflow
            }
        }
    }
}
