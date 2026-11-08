import SwiftUI

public enum DowntifyColor {
    // Brand primary accent
    public static let primary = Color(red: 0.11, green: 0.73, blue: 0.33) // #1DB954 Spotify/Downtify Green
    public static let primaryHover = Color(red: 0.13, green: 0.82, blue: 0.37)
    
    // Backgrounds
    public static let backgroundDark = Color(red: 0.07, green: 0.07, blue: 0.07) // #121212
    public static let backgroundAmoled = Color.black // #000000 True Black
    
    // Surfaces & Cards
    public static let surface = Color(red: 0.12, green: 0.12, blue: 0.12) // #1E1E1E
    public static let surfaceRaised = Color(red: 0.16, green: 0.16, blue: 0.16) // #282828
    public static let surfaceHighlight = Color(red: 0.20, green: 0.20, blue: 0.20) // #333333
    
    // Text roles
    public static let textPrimary = Color.white
    public static let textSecondary = Color(red: 0.70, green: 0.70, blue: 0.70) // #B3B3B3
    public static let textTertiary = Color(red: 0.45, green: 0.45, blue: 0.45) // #737373
    
    // States & Accents
    public static let error = Color(red: 0.95, green: 0.26, blue: 0.21)
    public static let warning = Color(red: 1.0, green: 0.76, blue: 0.03)
    public static let liked = Color(red: 0.93, green: 0.28, blue: 0.38) // Pink/red for liked songs
}

public class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    
    @Published public var isAmoledEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAmoledEnabled, forKey: "isAmoledEnabled")
        }
    }
    
    public init() {
        self.isAmoledEnabled = UserDefaults.standard.bool(forKey: "isAmoledEnabled")
    }
    
    public var currentBackground: Color {
        isAmoledEnabled ? DowntifyColor.backgroundAmoled : DowntifyColor.backgroundDark
    }
}
