import Testing
@testable import GreenReadCore

struct TrainScoringTests {
    private func guess(_ slope: Int, _ direction: BreakDirection) -> TrainGuess {
        TrainGuess(slopePercent: slope, breakDirection: direction, hill: .flat, aimInches: 12)
    }

    @Test func spotOn() {
        let score = TrainScoring.score(guess: guess(2, .rightToLeft), actual: SlopeReading(uphillPercent: 1, sidePercent: 2.1))
        #expect(score.verdict == .spotOn)
        #expect(score.points == 20)
        #expect(score.signedSlopeError == 0)
    }

    @Test func underAndOverRead() {
        let under = TrainScoring.score(guess: guess(1, .rightToLeft), actual: SlopeReading(uphillPercent: 0, sidePercent: 3))
        #expect(under.verdict == .underRead)
        #expect(under.points == 5)
        #expect(under.signedSlopeError == -2)

        let over = TrainScoring.score(guess: guess(3, .leftToRight), actual: SlopeReading(uphillPercent: 0, sidePercent: -2))
        #expect(over.verdict == .overRead)
        #expect(over.points == 12)
    }

    @Test func wrongWayLosesFivePointsButNeverGoesNegative() {
        let rightSlope = TrainScoring.score(guess: guess(2, .leftToRight), actual: SlopeReading(uphillPercent: 0, sidePercent: 2))
        #expect(rightSlope.verdict == .wrongWay)
        #expect(rightSlope.points == 15)

        let farOff = TrainScoring.score(guess: guess(4, .leftToRight), actual: SlopeReading(uphillPercent: 0, sidePercent: 1))
        #expect(farOff.verdict == .wrongWay)
        #expect(farOff.points == 0)
    }

    // Q4: rounded to the nearest whole %, clamped 1–4; under 0.5% is Straight.
    @Test func measuredSlopeIsRoundedAndClamped() {
        #expect(TrainScoring.scoredSlope(SlopeReading(uphillPercent: 0, sidePercent: 2.4)) == 2)
        #expect(TrainScoring.scoredSlope(SlopeReading(uphillPercent: 0, sidePercent: -2.6)) == 3)
        #expect(TrainScoring.scoredSlope(SlopeReading(uphillPercent: 0, sidePercent: 6.2)) == 4)
        #expect(TrainScoring.scoredSlope(SlopeReading(uphillPercent: 0, sidePercent: 0.3)) == 1)

        let straight = TrainScoring.score(guess: guess(1, .straight), actual: SlopeReading(uphillPercent: 0, sidePercent: 0.3))
        #expect(straight.verdict == .spotOn)
    }

    @Test func tendency() {
        #expect(TrainScoring.tendency(signedErrors: [-1, -2, 0, 1, 0]) == "You tend to under-read — trust more break.")
        #expect(TrainScoring.tendency(signedErrors: [1, 2, 0, -1, 1]) == "You tend to over-read — play a little less break.")
        #expect(TrainScoring.tendency(signedErrors: [1, -1, 0, 0, 0]) == "Nicely balanced reads this round.")
    }
}

struct StatsEngineTests {
    private func putt(
        round: Int = 0,
        feet: Double = 12,
        actual: Int,
        guessed: Int,
        direction: BreakDirection = .leftToRight,
        hill: Hill = .flat
    ) -> StatsPutt {
        StatsPutt(
            roundIndex: round,
            distanceFeet: feet,
            actualSlopePercent: actual,
            actualBreak: direction,
            actualHill: hill,
            guessedSlopePercent: guessed
        )
    }

    @Test func bucketsNeedTwoPuttsAndClampTo50() {
        let putts = [
            putt(actual: 3, guessed: 2),
            putt(actual: 3, guessed: 2),
            putt(actual: 1, guessed: 4, direction: .rightToLeft),
        ]
        let buckets = StatsEngine.buckets(putts)
        #expect(buckets.map(\.group) == [.leftToRight, .steep, .mid])
        #expect(buckets.first?.biasPercent == -33)
    }

    @Test func insightNamesTheGroupFurthestOff() {
        let putts = [
            putt(feet: 8, actual: 2, guessed: 2),
            putt(feet: 25, actual: 2, guessed: 2),
            putt(feet: 8, actual: 4, guessed: 2, direction: .rightToLeft),
            putt(feet: 25, actual: 3, guessed: 2, direction: .rightToLeft),
        ]
        #expect(StatsEngine.insight(putts) == "You under-read right-to-left putts by about 42%")
    }

    @Test func insightSaysImprovingWhenAGroupsMissShrinks() {
        // Only the uphill group has putts both before and in the last three rounds.
        let putts = [
            putt(round: 0, feet: 25, actual: 3, guessed: 4, direction: .rightToLeft, hill: .up),
            putt(round: 0, feet: 25, actual: 3, guessed: 2, direction: .rightToLeft, hill: .up),
            putt(round: 1, feet: 12, actual: 2, guessed: 2, hill: .up),
            putt(round: 2, feet: 12, actual: 2, guessed: 2, hill: .up),
            putt(round: 3, feet: 12, actual: 2, guessed: 2, hill: .up),
        ]
        #expect(StatsEngine.insight(putts) == "Your uphill reads are improving")
    }

    @Test func insightIsBalancedOtherwise() {
        let putts = [
            putt(actual: 2, guessed: 2),
            putt(actual: 2, guessed: 2),
        ]
        #expect(StatsEngine.insight(putts) == "Your reads are well balanced")
    }
}
