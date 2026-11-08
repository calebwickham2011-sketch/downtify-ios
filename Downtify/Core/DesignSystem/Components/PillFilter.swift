import SwiftUI

public struct PillFilter: View {
    public let title: String
    public let isSelected: Bool
    public let action: () -> Void
    
    public init(title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(DowntifyFont.label)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundColor(isSelected ? .black : DowntifyColor.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? DowntifyColor.primary : DowntifyColor.surfaceRaised)
                )
        }
        .buttonStyle(.plain)
    }
}
