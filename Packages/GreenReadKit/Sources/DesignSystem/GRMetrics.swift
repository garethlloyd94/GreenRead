import SwiftUI

/// Radii, sizes, spacing, shadows and motion from the handoff.
public enum GRMetrics {
    // Radii
    public static let chipRadius: CGFloat = 14
    public static let smallChipRadius: CGFloat = 12
    public static let cardRadius: CGFloat = 22
    public static let largeCardRadius: CGFloat = 26
    public static let sheetRadius: CGFloat = 30

    // Sizes
    public static let minTapTarget: CGFloat = 48
    public static let primaryButtonHeight: CGFloat = 56
    public static let segmentedHeight: CGFloat = 46
    public static let circleButton: CGFloat = 48
    public static let chipHeight: CGFloat = 52

    // Spacing
    public static let screenPadding: CGFloat = 18
    public static let cardPadding: CGFloat = 18
    public static let gap: CGFloat = 10
}

public enum GRMotion {
    /// Modal slide-up, 0.32 s ease-out.
    public static let modal = Animation.easeOut(duration: 0.32)
    /// Sheets, 0.3 s.
    public static let sheet = Animation.easeOut(duration: 0.3)
    /// Fades, 0.2–0.3 s.
    public static let fade = Animation.easeInOut(duration: 0.25)
    /// Lay-flat background colour change, 0.4 s.
    public static let stateColour = Animation.easeInOut(duration: 0.4)
    /// Pendulum swing per beat, 0.35 s ease-in-out.
    public static let pendulum = Animation.easeInOut(duration: 0.35)
}

extension View {
    /// Shadow for controls floating over the camera: 0 2 8 rgba(14,20,17,.15).
    public func floatingShadow() -> some View {
        shadow(color: GRColor.ink.opacity(0.15), radius: 4, x: 0, y: 2)
    }

    /// Shadow for popovers: 0 14 34 rgba(14,20,17,.35).
    public func popoverShadow() -> some View {
        shadow(color: GRColor.ink.opacity(0.35), radius: 17, x: 0, y: 14)
    }
}
