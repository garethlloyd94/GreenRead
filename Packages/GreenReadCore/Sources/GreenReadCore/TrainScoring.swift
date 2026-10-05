import Foundation

/// The golfer's read in Train mode, made before the phone measures.
public struct TrainGuess: Equatable, Sendable {
    /// 1–4 %.
    public var slopePercent: Int
    public var breakDirection: BreakDirection
    public var hill: Hill
    public var aimInches: Int

    public init(slopePercent: Int, breakDirection: BreakDirection, hill: Hill, aimInches: Int) {
        self.slopePercent = slopePercent
        self.breakDirection = breakDirection
        self.hill = hill
        self.aimInches = aimInches
    }
}

/// How one Train putt scored.
public struct PuttScore: Equatable, Sendable {
    public let verdict: Verdict
    public let points: Int
    /// The measured side slope as the whole percent it is scored against (1–4).
    public let actualSlopePercent: Int
    /// Guessed slope minus actual: negative is under-read, positive over-read.
    public let signedSlopeError: Int
}

/// Train scoring (prototype `lock()`, decision Q4).
///
/// - The measured slope is rounded to the nearest whole % and clamped to 1–4.
/// - Spot on: slope matches and the break direction is right. Wrong way: direction wrong.
///   Otherwise Under-read or Over-read by comparing slopes.
/// - Points: 20 / 12 / 5 for a slope error of 0 / 1 / 2+, then −5 for the wrong direction (minimum 0).
/// - Hill and aim are shown on the reveal but not scored.
public enum TrainScoring {
    public static let puttsPerRound = 5
    public static let slopeChoices = 1...4

    public static func score(guess: TrainGuess, actual: SlopeReading) -> PuttScore {
        let actualSlope = scoredSlope(actual)
        let isRightWay = guess.breakDirection == actual.breakDirection
        let error = guess.slopePercent - actualSlope

        let verdict: Verdict
        if !isRightWay {
            verdict = .wrongWay
        } else if error == 0 {
            verdict = .spotOn
        } else if error < 0 {
            verdict = .underRead
        } else {
            verdict = .overRead
        }

        var points: Int
        switch abs(error) {
        case 0: points = 20
        case 1: points = 12
        default: points = 5
        }
        if !isRightWay {
            points = max(0, points - 5)
        }
        return PuttScore(verdict: verdict, points: points, actualSlopePercent: actualSlope, signedSlopeError: error)
    }

    /// Side slope rounded to a whole percent and clamped to the 1–4 % guess chips.
    public static func scoredSlope(_ reading: SlopeReading) -> Int {
        let rounded = Int(abs(reading.sidePercent).rounded())
        return min(max(rounded, slopeChoices.lowerBound), slopeChoices.upperBound)
    }

    /// The summary's one-line tendency.
    public static func tendency(signedErrors: [Int]) -> String {
        let unders = signedErrors.filter { $0 < 0 }.count
        let overs = signedErrors.filter { $0 > 0 }.count
        if unders > overs {
            return "You tend to under-read — trust more break."
        } else if overs > unders {
            return "You tend to over-read — play a little less break."
        } else {
            return "Nicely balanced reads this round."
        }
    }
}
