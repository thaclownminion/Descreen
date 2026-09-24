import SwiftUI

// Theme system for settings window only
// Break overlays and notifications are always dark mode
enum AppTheme: String, CaseIterable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var backgroundColor: Color {
        switch self {
        case .system:
            return Color(NSColor.windowBackgroundColor)
        case .light:
            return Color.white
        case .dark:
            return Color(white: 0.1)
        }
    }
}

