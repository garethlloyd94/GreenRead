import SwiftUI

/// Colour tokens from the design handoff. Light mode only for v1.
enum GRColor {
    // Neutrals
    static let ink = Color(hex: 0x0E1411)            // text, primary neutral buttons, dark cards
    static let chalk = Color(hex: 0xF5F6F2)          // app background
    static let card = Color.white
    static let textSecondary = Color(hex: 0x5B635D)  // "Moss grey"
    static let textMuted = Color(hex: 0x8A918B)
    static let textOnDarkMuted = Color(hex: 0xC5CAC2)
    static let border = Color(hex: 0xDADDD5)
    static let fill = Color(hex: 0xEEF0EA)           // dividers, light fills
    static let fillStrong = Color(hex: 0xE3E6DE)     // secondary buttons, segmented track

    // Brand and state
    static let green = Color(hex: 0x1E9E5A)          // go, aim, spot on, selected
    static let greenPressed = Color(hex: 0x147A43)
    static let greenTint = Color(hex: 0xE3F2E8)
    static let greenTintText = Color(hex: 0x0E5A31)
    static let lime = Color(hex: 0xD4F53C)           // AR overlays and highlights on dark only
    static let clay = Color(hex: 0xD9622B)           // under-read, wrong way, warnings
    static let clayTint = Color(hex: 0xFBE7DD)
    static let clayTintText = Color(hex: 0x6B2C10)
    static let clayOnDark = Color(hex: 0xFFB08A)      // mismatched values on dark reveal card
    static let slate = Color(hex: 0x4A6FA5)          // over-read

    // Camera placeholder stripes (previews only; real screens show the live camera)
    static let turfDark = Color(hex: 0x3E5A44)
    static let turfLight = Color(hex: 0x466349)
    static let thumbDark = Color(hex: 0xDDE5D8)
    static let thumbLight = Color(hex: 0xE5ECE1)
}

extension Color {
    /// `Color(hex: 0x1E9E5A)`
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
