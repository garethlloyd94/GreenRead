import Foundation

/// Whether the putt runs uphill, downhill or flat toward the hole.
public enum Hill: String, Codable, CaseIterable, Sendable {
    case up, flat, down

    /// Below this many percent of slope along the line, a putt counts as flat.
    public static let flatThresholdPercent = 0.5

    /// - Parameter uphillPercent: slope along the line; positive is uphill toward the hole.
    public init(uphillPercent: Double) {
        if abs(uphillPercent) < Hill.flatThresholdPercent {
            self = .flat
        } else {
            self = uphillPercent > 0 ? .up : .down
        }
    }

    public var label: String {
        switch self {
        case .up: "Up"
        case .flat: "Flat"
        case .down: "Down"
        }
    }
}

/// Which way the ball breaks, seen from behind the ball looking at the hole.
public enum BreakDirection: String, Codable, CaseIterable, Sendable {
    case leftToRight, rightToLeft, straight

    /// Below this many percent of side slope, a putt counts as straight.
    public static let straightThresholdPercent = 0.5

    /// - Parameter sidePercent: side slope across the line. Positive means the green
    ///   falls from right to left, so the ball breaks right to left.
    public init(sidePercent: Double) {
        if abs(sidePercent) < BreakDirection.straightThresholdPercent {
            self = .straight
        } else {
            self = sidePercent > 0 ? .rightToLeft : .leftToRight
        }
    }

    public var label: String {
        switch self {
        case .leftToRight: "L→R"
        case .rightToLeft: "R→L"
        case .straight: "Straight"
        }
    }

    /// The side of the hole to aim at: a putt breaking right to left is aimed right.
    public var aimSide: AimSide {
        switch self {
        case .leftToRight: .left
        case .rightToLeft: .right
        case .straight: .centre
        }
    }
}

public enum AimSide: String, Codable, Sendable {
    case left, right, centre

    /// Short suffix used after the aim number, e.g. "16in R".
    public var shortLabel: String {
        switch self {
        case .left: "L"
        case .right: "R"
        case .centre: ""
        }
    }
}

/// A slope measurement with the phone's top edge pointing at the hole.
public struct SlopeReading: Equatable, Sendable {
    /// Slope along the line; positive is uphill toward the hole.
    public var uphillPercent: Double
    /// Slope across the line; positive means the ball breaks right to left.
    public var sidePercent: Double

    public init(uphillPercent: Double, sidePercent: Double) {
        self.uphillPercent = uphillPercent
        self.sidePercent = sidePercent
    }

    public var hill: Hill { Hill(uphillPercent: uphillPercent) }
    public var breakDirection: BreakDirection { BreakDirection(sidePercent: sidePercent) }

    /// Side slope rounded to the whole percent the Tour Read method works in.
    public var wholeSlopePercent: Int {
        breakDirection == .straight ? 0 : Int(abs(sidePercent).rounded())
    }
}
