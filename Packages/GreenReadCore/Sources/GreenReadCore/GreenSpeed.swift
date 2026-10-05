import Foundation

/// Green speed as a Stimpmeter reading. Medium (Stimp 10) is the reference speed
/// the Tour Read numbers are scaled from.
public struct GreenSpeed: Equatable, Hashable, Codable, Sendable {
    public static let referenceStimp = 10.0
    public static let stimpRange: ClosedRange<Double> = 6...14

    public static let slow = GreenSpeed(stimp: 8)
    public static let medium = GreenSpeed(stimp: 10)
    public static let fast = GreenSpeed(stimp: 12)
    public static let presets: [GreenSpeed] = [.slow, .medium, .fast]

    /// Clamped to `stimpRange` and rounded to one decimal place, so equal readings compare equal.
    public let stimp: Double

    public init(stimp: Double) {
        let clamped = min(max(stimp, GreenSpeed.stimpRange.lowerBound), GreenSpeed.stimpRange.upperBound)
        self.stimp = (clamped * 10).rounded() / 10
    }

    private enum CodingKeys: String, CodingKey {
        case stimp
    }

    /// Decodes through `init(stimp:)`, so an out-of-range value on disk is clamped.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(stimp: try container.decode(Double.self, forKey: .stimp))
    }

    /// Faster greens break more: aim is scaled by Stimp ÷ 10.
    public var breakFactor: Double { stimp / GreenSpeed.referenceStimp }

    /// "Slow", "Medium" or "Fast" for the presets, otherwise nil.
    public var presetName: String? {
        switch self {
        case .slow: "Slow"
        case .medium: "Medium"
        case .fast: "Fast"
        default: nil
        }
    }

    /// "Medium" for presets, "Stimp 11" for anything else.
    public var displayName: String {
        presetName ?? "Stimp \(GreenSpeed.formatStimp(stimp))"
    }

    /// "Stimp 10"
    public var stimpLabel: String { "Stimp \(GreenSpeed.formatStimp(stimp))" }

    static func formatStimp(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}
