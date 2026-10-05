import CoreText
import SwiftUI
import UIKit

/// Archivo (variable: weight 100–900, width 62–125) and JetBrains Mono (variable: weight 100–800),
/// bundled under Resources/Fonts and registered at launch.
public enum GRFont {

    /// Registers every bundled .ttf for this process. Call once at launch.
    public static func registerBundledFonts() {
        let urls = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// Archivo at an exact weight (100–900) and width (62–125, 100 = normal).
    /// Headlines and numbers use weight 800 at width 110–120.
    public static func archivo(_ size: CGFloat, weight: CGFloat = 400, width: CGFloat = 100) -> Font {
        Font(uiArchivo(size, weight: weight, width: width))
    }

    /// JetBrains Mono, used at weight 600 for small uppercase labels.
    public static func mono(_ size: CGFloat, weight: CGFloat = 600) -> Font {
        Font(uiMono(size, weight: weight))
    }

    public static func uiArchivo(_ size: CGFloat, weight: CGFloat, width: CGFloat) -> UIFont {
        variableFont(postScriptName: archivoPostScriptName, size: size, axes: [
            Axis.weight: weight,
            Axis.width: width
        ]) ?? UIFont.systemFont(ofSize: size, weight: systemWeight(for: weight), width: systemWidth(for: width))
    }

    public static func uiMono(_ size: CGFloat, weight: CGFloat) -> UIFont {
        variableFont(postScriptName: monoPostScriptName, size: size, axes: [Axis.weight: weight])
            ?? UIFont.monospacedSystemFont(ofSize: size, weight: systemWeight(for: weight))
    }

    // MARK: - Private

    /// PostScript names of the default instances inside the variable font files.
    private static let archivoPostScriptName = "Archivo-SemiBold"
    private static let monoPostScriptName = "JetBrainsMono-Regular"

    /// OpenType axis tags as four-character codes.
    private enum Axis {
        static let weight = 0x7767_6874 // 'wght'
        static let width = 0x7764_7468  // 'wdth'
    }

    private static func variableFont(postScriptName: String, size: CGFloat, axes: [Int: CGFloat]) -> UIFont? {
        guard UIFont(name: postScriptName, size: size) != nil else { return nil }
        let variations = Dictionary(uniqueKeysWithValues: axes.map { (NSNumber(value: $0.key), NSNumber(value: Double($0.value))) })
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: postScriptName,
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variations
        ])
        return UIFont(descriptor: descriptor, size: size)
    }

    private static func systemWeight(for weight: CGFloat) -> UIFont.Weight {
        switch weight {
        case ..<350: .light
        case ..<450: .regular
        case ..<550: .medium
        case ..<650: .semibold
        case ..<750: .bold
        case ..<850: .heavy
        default: .black
        }
    }

    private static func systemWidth(for width: CGFloat) -> UIFont.Width {
        switch width {
        case ..<90: .condensed
        case ..<108: .standard
        default: .expanded
        }
    }
}

/// Named text styles used across the app, matching the handoff's type scale.
/// Tracking is given in em and converted to points for the font size.
/// Mono label strings are written in uppercase at the call site ("ACTUAL", "AIM").
public struct GRTextStyle: Sendable {
    public enum Family: Sendable { case archivo, mono }

    public let family: Family
    public let size: CGFloat
    public let weight: CGFloat
    public let width: CGFloat
    public let trackingEm: CGFloat

    public var font: Font {
        switch family {
        case .archivo: GRFont.archivo(size, weight: weight, width: width)
        case .mono: GRFont.mono(size, weight: weight)
        }
    }

    public var tracking: CGFloat { size * trackingEm }

    // Archivo display and numbers (800, expanded)
    public static let aimHero = GRTextStyle(family: .archivo, size: 56, weight: 800, width: 115, trackingEm: -0.03)
    public static let display = GRTextStyle(family: .archivo, size: 34, weight: 800, width: 110, trackingEm: -0.02)
    public static let title = GRTextStyle(family: .archivo, size: 24, weight: 800, width: 110, trackingEm: -0.02)
    public static let number = GRTextStyle(family: .archivo, size: 20, weight: 800, width: 100, trackingEm: -0.01)
    public static let tileTitle = GRTextStyle(family: .archivo, size: 22, weight: 800, width: 105, trackingEm: -0.01)

    // Archivo text
    public static let button = GRTextStyle(family: .archivo, size: 16, weight: 700, width: 100, trackingEm: 0)
    public static let headline = GRTextStyle(family: .archivo, size: 15, weight: 700, width: 100, trackingEm: 0)
    public static let body = GRTextStyle(family: .archivo, size: 15, weight: 500, width: 100, trackingEm: 0)
    public static let chip = GRTextStyle(family: .archivo, size: 13, weight: 700, width: 100, trackingEm: 0)
    public static let caption = GRTextStyle(family: .archivo, size: 12, weight: 500, width: 100, trackingEm: 0)

    // JetBrains Mono labels (ACTUAL · PLAYS · AIM)
    public static let label = GRTextStyle(family: .mono, size: 11, weight: 600, width: 100, trackingEm: 0.08)
    public static let labelSmall = GRTextStyle(family: .mono, size: 10, weight: 600, width: 100, trackingEm: 0.08)
    public static let working = GRTextStyle(family: .mono, size: 13, weight: 500, width: 100, trackingEm: 0)

    public init(
        family: Family,
        size: CGFloat,
        weight: CGFloat,
        width: CGFloat,
        trackingEm: CGFloat
    ) {
        self.family = family
        self.size = size
        self.weight = weight
        self.width = width
        self.trackingEm = trackingEm
    }
}

extension View {
    /// Applies a GreenRead text style: font and tracking.
    public func grTextStyle(_ style: GRTextStyle) -> some View {
        font(style.font).tracking(style.tracking)
    }
}

extension Text {
    /// `Text("AIM").gr(.label)` renders in JetBrains Mono with label tracking.
    public func gr(_ style: GRTextStyle) -> Text {
        font(style.font).tracking(style.tracking)
    }
}
