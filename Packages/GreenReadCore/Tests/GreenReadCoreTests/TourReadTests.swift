import Testing
@testable import GreenReadCore

struct TourReadTests {

    // README example: 15 ft, 2% R→L, uphill → 9in × 2 = 18 − 2 = 16in right.
    @Test func readmeExample() {
        let result = TourRead.read(feet: 15, slope: SlopeReading(uphillPercent: 1.2, sidePercent: 2))
        #expect(result.breakdown.onePercentInches == 9)
        #expect(result.breakdown.scaledInches == 18)
        #expect(result.breakdown.hillAdjustmentInches == -2)
        #expect(result.aimInches == 16)
        #expect(result.breakDirection == .rightToLeft)
        #expect(result.aimSide == .right)
        #expect(Format.aim(inches: result.aimInches, unit: .inches, side: result.aimSide).text == "16in R")
    }

    // Design pack 5a: 2.1% side slope is read as 2% in the working, still 16in R.
    @Test func decimalSideSlopeRoundsToWholePercent() {
        let result = TourRead.read(feet: 15, slope: SlopeReading(uphillPercent: 1.2, sidePercent: 2.1))
        #expect(result.breakdown.slopePercent == 2)
        #expect(result.aimInches == 16)
    }

    @Test func onePercentBreak() {
        #expect(TourRead.onePercentBreak(feet: 15) == 9)   // 5 yd × 2 − 1
        #expect(TourRead.onePercentBreak(feet: 30) == 19)  // 10 yd × 2 − 1
        #expect(TourRead.onePercentBreak(feet: 8) == 4)    // 2.67 × 2 − 1 = 4.33
        #expect(TourRead.onePercentBreak(feet: 3) == 1)    // minimum 1
        #expect(TourRead.onePercentBreak(feet: 1) == 1)
    }

    @Test func downhillAddsSlope() {
        #expect(TourRead.aimInches(feet: 20, slopePercent: 2, hill: .down) == 26) // 12 × 2 + 2
    }

    @Test func flatHasNoAdjustment() {
        #expect(TourRead.aimInches(feet: 12, slopePercent: 3, hill: .flat) == 21) // 7 × 3
    }

    @Test func straightPuttAimsCentre() {
        let result = TourRead.read(feet: 10, slope: SlopeReading(uphillPercent: 2, sidePercent: 0.3))
        #expect(result.breakDirection == .straight)
        #expect(result.aimInches == 0)
        #expect(result.aimSide == .centre)
    }

    @Test func aimNeverNegative() {
        #expect(TourRead.aimInches(feet: 3, slopePercent: 1, hill: .up) == 0) // 1 × 1 − 1
    }

    @Test func greenSpeedScalesAim() {
        #expect(TourRead.aimInches(feet: 15, slopePercent: 2, hill: .up, speed: .slow) == 13)  // 16 × 0.8 = 12.8
        #expect(TourRead.aimInches(feet: 15, slopePercent: 2, hill: .up, speed: .medium) == 16)
        #expect(TourRead.aimInches(feet: 15, slopePercent: 2, hill: .up, speed: .fast) == 19)  // 16 × 1.2 = 19.2
    }

    @Test func leftToRightAimsLeft() {
        let result = TourRead.read(feet: 12, slope: SlopeReading(uphillPercent: 0, sidePercent: -3))
        #expect(result.breakDirection == .leftToRight)
        #expect(result.aimSide == .left)
        #expect(result.aimInches == 21)
    }

    // Design examples: 15 ft at 1.2% uphill plays like 17 ft on a Medium green.
    @Test func playsLike() {
        #expect(abs(TourRead.playsLikeFeet(feet: 15, uphillPercent: 1.2) - 16.8) < 0.0001)
        #expect(Format.distance(feet: TourRead.playsLikeFeet(feet: 15, uphillPercent: 1.2), unit: .feet) == "17 ft")
        #expect(abs(TourRead.playsLikeFeet(feet: 10, uphillPercent: 2) - 12) < 0.0001)
        #expect(abs(TourRead.playsLikeFeet(feet: 20, uphillPercent: -2) - 16) < 0.0001)
        #expect(abs(TourRead.playsLikeFeet(feet: 10, uphillPercent: 2, speed: .fast) - 12.4) < 0.0001)
        #expect(abs(TourRead.playsLikeFeet(feet: 2, uphillPercent: -60) - 1) < 0.0001) // floor of 1 ft
    }

    @Test func hillAndBreakThresholds() {
        #expect(Hill(uphillPercent: 0.4) == .flat)
        #expect(Hill(uphillPercent: 0.5) == .up)
        #expect(Hill(uphillPercent: -0.7) == .down)
        #expect(BreakDirection(sidePercent: -0.49) == .straight)
        #expect(BreakDirection(sidePercent: 0.5) == .rightToLeft)
        #expect(BreakDirection(sidePercent: -1) == .leftToRight)
    }

    @Test func greenSpeedClampsAndNames() {
        #expect(GreenSpeed(stimp: 20).stimp == 14)
        #expect(GreenSpeed(stimp: 2).stimp == 6)
        #expect(GreenSpeed.medium.displayName == "Medium")
        #expect(GreenSpeed(stimp: 11).displayName == "Stimp 11")
        #expect(GreenSpeed.medium.breakFactor == 1)
        #expect(abs(GreenSpeed.fast.breakFactor - 1.2) < 0.0001)
    }
}
