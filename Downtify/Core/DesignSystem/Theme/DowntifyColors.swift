import SwiftUI

public enum DowntifyAccentColor: String, CaseIterable, Identifiable {
    case green   = "Downtify Green"
    case spotify = "Spotify Green"
    case blue    = "Electric Blue"
    case orange  = "Sunset Orange"
    case purple  = "Royal Purple"
    case pink    = "Neon Pink"
    case amber   = "Gold Amber"
    case teal    = "Cyan Teal"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .green:   return Color(red: 0.10, green: 0.82, blue: 0.36) // #1AD05C Brand
        case .spotify: return Color(red: 0.11, green: 0.73, blue: 0.33) // #1DB954
        case .blue:    return Color(red: 0.18, green: 0.53, blue: 0.98) // #2E86DE
        case .orange:  return Color(red: 1.00, green: 0.47, blue: 0.25) // #FF793F
        case .purple:  return Color(red: 0.65, green: 0.28, blue: 0.88) // #A548E1
        case .pink:    return Color(red: 0.95, green: 0.26, blue: 0.58) // #F34294
        case .amber:   return Color(red: 1.00, green: 0.76, blue: 0.03) // #FFC107
        case .teal:    return Color(red: 0.00, green: 0.81, blue: 0.79) // #00CEC9
        }
    }
}

public enum DowntifyColor {
    // Brand primary accent — dynamically follows user selection
    public static var primary: Color {
        ThemeManager.savedAccent.color
    }
    public static let primaryHover = Color(red: 0.13, green: 0.82, blue: 0.37)

    // Backgrounds
    public static let backgroundDark = Color(red: 0.07, green: 0.07, blue: 0.07) // #121212
    public static let backgroundAmoled = Color.black // #000000 True Black
    public static let backgroundLight = Color(red: 0.96, green: 0.96, blue: 0.97)

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

@MainActor
public class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()

    public nonisolated static var savedAccent: DowntifyAccentColor {
        let raw = UserDefaults.standard.string(forKey: "selectedAccentColor") ?? DowntifyAccentColor.green.rawValue
        return DowntifyAccentColor(rawValue: raw) ?? .green
    }

    @Published public var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }

    @Published public var isAmoledEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAmoledEnabled, forKey: "isAmoledEnabled")
        }
    }

    @Published public var selectedAccent: DowntifyAccentColor {
        didSet {
            UserDefaults.standard.set(selectedAccent.rawValue, forKey: "selectedAccentColor")
        }
    }

    public init() {
        let savedDark = UserDefaults.standard.object(forKey: "isDarkMode")
        self.isDarkMode = (savedDark as? Bool) ?? true

        self.isAmoledEnabled = UserDefaults.standard.bool(forKey: "isAmoledEnabled")

        let savedAccent = UserDefaults.standard.string(forKey: "selectedAccentColor") ?? DowntifyAccentColor.green.rawValue
        self.selectedAccent = DowntifyAccentColor(rawValue: savedAccent) ?? .green
    }

    public var currentAccentColor: Color {
        selectedAccent.color
    }

    public var currentBackground: Color {
        if !isDarkMode {
            return DowntifyColor.backgroundLight
        }
        return isAmoledEnabled ? DowntifyColor.backgroundAmoled : DowntifyColor.backgroundDark
    }
}
