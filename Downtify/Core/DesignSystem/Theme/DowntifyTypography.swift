import SwiftUI

public enum DowntifyFont {
    // Display and large headers
    public static let hero = Font.system(size: 32, weight: .bold, design: .rounded)
    public static let pageTitle = Font.system(size: 26, weight: .bold, design: .rounded)
    public static let sectionTitle = Font.system(size: 20, weight: .bold, design: .rounded)
    
    // Content & Cards
    public static let cardTitle = Font.system(size: 15, weight: .semibold, design: .rounded)
    public static let cardSubtitle = Font.system(size: 13, weight: .medium, design: .rounded)
    
    // Body & navigation
    public static let body = Font.system(size: 15, weight: .regular, design: .rounded)
    public static let bodyBold = Font.system(size: 15, weight: .semibold, design: .rounded)
    public static let label = Font.system(size: 12, weight: .medium, design: .rounded)
    public static let caption = Font.system(size: 11, weight: .regular, design: .rounded)
    
    // Data values (durations, bitrates, sample rates) with tabular numbers
    public static let dataValue = Font.system(size: 12, weight: .medium, design: .monospaced)
}
