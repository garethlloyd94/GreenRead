import SwiftUI

/// Colour tokens from the design handoff, backed by `Resources/Colors.xcassets`.
/// Light mode only for v1; the catalog is where dark and Increase Contrast variants go.
public enum GRColor {
    // Neutrals
    public static let ink = Color(.ink)            // text, primary neutral buttons, dark cards
    public static let chalk = Color(.chalk)          // app background
    public static let card = Color.white
    public static let textSecondary = Color(.textSecondary)  // "Moss grey"
    public static let textMuted = Color(.textMuted)
    public static let textOnDarkMuted = Color(.textOnDarkMuted)
    public static let border = Color(.border)
    public static let fill = Color(.fill)           // dividers, light fills
    public static let fillStrong = Color(.fillStrong)     // secondary buttons, segmented track

    // Brand and state
    public static let green = Color(.green)          // go, aim, spot on, selected
    public static let greenPressed = Color(.greenPressed)
    public static let greenTint = Color(.greenTint)
    public static let greenTintText = Color(.greenTintText)
    public static let lime = Color(.lime)           // AR overlays and highlights on dark only
    public static let clay = Color(.clay)           // under-read, wrong way, warnings
    public static let clayTint = Color(.clayTint)
    public static let clayTintText = Color(.clayTintText)
    public static let clayOnDark = Color(.clayOnDark)      // mismatched values on dark reveal card
    public static let slate = Color(.slate)          // over-read

    // Camera placeholder stripes (previews only; real screens show the live camera)
    public static let turfDark = Color(.turfDark)
    public static let turfLight = Color(.turfLight)
    public static let thumbDark = Color(.thumbDark)
    public static let thumbLight = Color(.thumbLight)
    public static let videoDark = Color(.videoDark)
    public static let videoLight = Color(.videoLight)
}
