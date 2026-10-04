import Foundation

public enum DistanceUnit: String, Codable, CaseIterable, Sendable {
    case feet, metres

    public static let metresPerFoot = 0.3048

    /// Segmented-control label: "ft" / "m".
    public var shortLabel: String {
        switch self {
        case .feet: "ft"
        case .metres: "m"
        }
    }
}

/// How aim numbers are shown. Aim is always stored in inches.
public enum AimUnit: String, Codable, CaseIterable, Sendable {
    case inches, cups, balls

    public static let inchesPerCup = 4.25
    public static let inchesPerBall = 1.68

    /// Settings label: "Inches" / "Cups" / "Balls".
    public var title: String {
        switch self {
        case .inches: "Inches"
        case .cups: "Cups"
        case .balls: "Balls"
        }
    }
}

/// An aim number split into parts, so the unit can be styled smaller than the value.
public struct AimDisplay: Equatable, Sendable {
    /// "16", "3.5", "10"
    public let value: String
    /// "in", "cups", "balls"
    public let unit: String
    /// "R", "L" or "".
    public let side: String

    /// "16in", "1 cup", "3.5 cups", "10 balls"
    public var amount: String {
        unit == "in" ? "\(value)in" : "\(value) \(unit)"
    }

    /// "16in R", "4 cups L", "0in"
    public var text: String {
        side.isEmpty ? amount : "\(amount) \(side)"
    }
}

public enum Format {

    /// Aim in the chosen unit. Cups round to the nearest half, balls to a whole number.
    public static func aim(inches: Int, unit: AimUnit, side: AimSide = .centre) -> AimDisplay {
        let sideLabel = inches == 0 ? "" : side.shortLabel
        switch unit {
        case .inches:
            return AimDisplay(value: String(inches), unit: "in", side: sideLabel)
        case .cups:
            let cups = (Double(inches) / AimUnit.inchesPerCup * 2).rounded() / 2
            return AimDisplay(value: number(cups), unit: cups == 1 ? "cup" : "cups", side: sideLabel)
        case .balls:
            let balls = Int((Double(inches) / AimUnit.inchesPerBall).rounded())
            return AimDisplay(value: String(balls), unit: balls == 1 ? "ball" : "balls", side: sideLabel)
        }
    }

    /// Signed aim amount for the working panel, e.g. "−2in" or "+0.5 cups".
    public static func signedAim(inches: Int, unit: AimUnit) -> String {
        let magnitude = aim(inches: abs(inches), unit: unit).amount
        if inches < 0 { return "−" + magnitude }
        if inches > 0 { return "+" + magnitude }
        return magnitude
    }

    /// Whole feet ("15 ft") or metres to one decimal ("4.6 m").
    public static func distance(feet: Double, unit: DistanceUnit) -> String {
        switch unit {
        case .feet:
            return "\(Int(feet.rounded())) ft"
        case .metres:
            return String(format: "%.1f m", feet * DistanceUnit.metresPerFoot)
        }
    }

    /// Slope to one decimal: "2.1%".
    public static func slope(percent: Double) -> String {
        String(format: "%.1f%%", abs(percent))
    }

    /// Yards to one decimal, dropping ".0": "5 yd", "6.7 yd".
    public static func yards(feet: Double) -> String {
        "\(number((feet / 3 * 10).rounded() / 10)) yd"
    }

    /// "3.5" stays "3.5"; "4.0" becomes "4".
    static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}
