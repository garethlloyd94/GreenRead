import SwiftUI

/// Radii, sizes, spacing, shadows and motion from the handoff.
enum GRMetrics {
    // Radii
    static let chipRadius: CGFloat = 14
    static let smallChipRadius: CGFloat = 12
    static let cardRadius: CGFloat = 22
    static let largeCardRadius: CGFloat = 26
    static let sheetRadius: CGFloat = 30

    // Sizes
    static let minTapTarget: CGFloat = 48
    static let primaryButtonHeight: CGFloat = 56
    static let segmentedHeight: CGFloat = 46
    static let circleButton: CGFloat = 48
    static let chipHeight: CGFloat = 52

    // Spacing
    static let screenPadding: CGFloat = 18
    static let cardPadding: CGFloat = 18
    static let gap: CGFloat = 10
}

enum GRMotion {
    /// Modal slide-up, 0.32 s ease-out.
    static let modal = Animation.easeOut(duration: 0.32)
    /// Sheets, 0.3 s.
    static let sheet = Animation.easeOut(duration: 0.3)
    /// Fades, 0.2–0.3 s.
    static let fade = Animation.easeInOut(duration: 0.25)
    /// Lay-flat background colour change, 0.4 s.
    static let stateColour = Animation.easeInOut(duration: 0.4)
    /// Pendulum swing per beat, 0.35 s ease-in-out.
    static let pendulum = Animation.easeInOut(duration: 0.35)
}

extension View {
    /// Shadow for controls floating over the camera: 0 2 8 rgba(14,20,17,.15).
    func floatingShadow() -> some View {
        shadow(color: GRColor.ink.opacity(0.15), radius: 4, x: 0, y: 2)
    }

    /// Shadow for popovers: 0 14 34 rgba(14,20,17,.35).
    func popoverShadow() -> some View {
        shadow(color: GRColor.ink.opacity(0.35), radius: 17, x: 0, y: 14)
    }
}
