import Foundation

/// The Tour Read aim method, scaled for green speed.
///
///     yards  = feet / 3
///     base   = max(1, round(yards × 2 − 1))      // inches of break at 1%
///     aim    = base × slope%
///     uphill → aim −= slope%     downhill → aim += slope%
///     aim    = max(0, round(aim × stimp / 10))
///
/// Example: 15 ft, 2% R→L, uphill, Medium green → 9 × 2 = 18 − 2 = 16in right.
public enum TourRead {

    /// Inches of break at 1% slope for a putt of this length.
    public static func onePercentBreak(feet: Double) -> Int {
        max(1, Int((feet / 3 * 2 - 1).rounded()))
    }

    /// Inches outside the hole to aim, rounded to the nearest inch.
    public static func aimInches(feet: Double, slopePercent: Int, hill: Hill, speed: GreenSpeed = .medium) -> Int {
        breakdown(feet: feet, slopePercent: slopePercent, hill: hill, speed: speed).aimInches
    }

    /// Every step of the sum, for the "How we got this" panel.
    public static func breakdown(feet: Double, slopePercent: Int, hill: Hill, speed: GreenSpeed = .medium) -> AimBreakdown {
        let base = onePercentBreak(feet: feet)
        let slope = max(0, slopePercent)
        let scaled = base * slope
        let hillAdjustment: Int
        switch hill {
        case .up: hillAdjustment = -slope
        case .down: hillAdjustment = slope
        case .flat: hillAdjustment = 0
        }
        let beforeSpeed = Double(scaled + hillAdjustment)
        let aim = max(0, Int((beforeSpeed * speed.breakFactor).rounded()))
        return AimBreakdown(
            feet: feet,
            yards: feet / 3,
            onePercentInches: base,
            slopePercent: slope,
            scaledInches: scaled,
            hill: hill,
            hillAdjustmentInches: hillAdjustment,
            speed: speed,
            aimInches: aim
        )
    }

    /// Full read from a measured distance and slope.
    public static func read(feet: Double, slope: SlopeReading, speed: GreenSpeed = .medium) -> AimResult {
        let direction = slope.breakDirection
        let wholeSlope = slope.wholeSlopePercent
        return AimResult(
            reading: slope,
            breakDirection: direction,
            breakdown: breakdown(feet: feet, slopePercent: wholeSlope, hill: slope.hill, speed: speed),
            playsLikeFeet: playsLikeFeet(feet: feet, uphillPercent: slope.uphillPercent, speed: speed)
        )
    }

    /// How long the putt plays. Coaches' rule: for every 10 ft, add slope% × Stimp ÷ 10 feet
    /// uphill (subtract downhill), i.e. feet × (1 + uphill% × Stimp ÷ 100).
    ///
    /// Example: 15 ft at 1.2% uphill on Stimp 10 → 16.8 → plays like 17 ft.
    public static func playsLikeFeet(feet: Double, uphillPercent: Double, speed: GreenSpeed = .medium) -> Double {
        max(1, feet * (1 + uphillPercent * speed.stimp / 100))
    }
}

/// The working behind an aim number.
public struct AimBreakdown: Equatable, Sendable {
    public let feet: Double
    public let yards: Double
    /// Inches of break at 1% slope.
    public let onePercentInches: Int
    public let slopePercent: Int
    /// `onePercentInches × slopePercent`.
    public let scaledInches: Int
    public let hill: Hill
    /// Negative uphill, positive downhill, zero when flat.
    public let hillAdjustmentInches: Int
    public let speed: GreenSpeed
    /// Final aim in inches outside the hole.
    public let aimInches: Int

    /// True when the green-speed step changes the number (anything but Stimp 10).
    public var hasSpeedAdjustment: Bool { speed.stimp != GreenSpeed.referenceStimp }
}

public struct AimResult: Equatable, Sendable {
    public let reading: SlopeReading
    public let breakDirection: BreakDirection
    public let breakdown: AimBreakdown
    public let playsLikeFeet: Double

    public var aimInches: Int { breakdown.aimInches }
    public var aimSide: AimSide { aimInches == 0 ? .centre : breakDirection.aimSide }
}
