import SwiftUI

public struct SectionHeader: View {
    public let title: String
    public var actionTitle: String? = nil
    public var onAction: (() -> Void)? = nil
    
    public init(title: String, actionTitle: String? = nil, onAction: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.onAction = onAction
    }
    
    public var body: some View {
        HStack {
            Text(title)
                .font(DowntifyFont.sectionTitle)
                .foregroundColor(DowntifyColor.textPrimary)
            
            Spacer()
            
            if let actionTitle = actionTitle {
                Button(action: { onAction?() }) {
                    Text(actionTitle)
                        .font(DowntifyFont.label)
                        .foregroundColor(DowntifyColor.primary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}
