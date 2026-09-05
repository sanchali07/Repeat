import SwiftUI

/// The app's palette. Ink and paper are two separate worlds: the chrome is deep
/// navy, the generated paper is warm cream. Heat is the only strong colour, and
/// it is reserved for how often a question repeats.
enum Theme {
    static let ink       = Color(red: 0.055, green: 0.071, blue: 0.110)
    static let surface   = Color(red: 0.086, green: 0.106, blue: 0.157)
    static let raised    = Color(red: 0.102, green: 0.125, blue: 0.180)
    static let line      = Color(red: 0.161, green: 0.188, blue: 0.247)
    static let fg        = Color(red: 0.925, green: 0.937, blue: 0.961)
    static let fg2       = Color(red: 0.592, green: 0.631, blue: 0.710)
    static let fg3       = Color(red: 0.392, green: 0.431, blue: 0.522)
    static let paper     = Color(red: 0.957, green: 0.937, blue: 0.894)
    static let paperInk  = Color(red: 0.106, green: 0.094, blue: 0.082)

    /// Repeat frequency as temperature: cool grey for a one-off, hot coral for a
    /// question the examiner cannot stop asking.
    static func heat(_ occurrences: Int) -> Color {
        switch occurrences {
        case ...1: Color(red: 0.349, green: 0.384, blue: 0.478)
        case 2:    Color(red: 0.541, green: 0.525, blue: 0.592)
        case 3:    Color(red: 0.753, green: 0.541, blue: 0.271)
        case 4:    Color(red: 0.824, green: 0.447, blue: 0.227)
        default:   Color(red: 0.867, green: 0.333, blue: 0.251)
        }
    }

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}
