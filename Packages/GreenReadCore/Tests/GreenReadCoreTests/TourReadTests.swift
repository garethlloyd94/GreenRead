import XCTest
@testable import GreenReadCore

final class TourReadTests: XCTestCase {

    // README example: 15 ft, 2% R→L, uphill → 9in × 2 = 18 − 2 = 16in right.
    func testReadmeExample() {
        let result = TourRead.read(feet: 15, slope: SlopeReading(uphillPercent: 1.2, sidePercent: 2))
        XCTAssertEqual(result.breakdown.onePercentInches, 9)
        XCTAssertEqual(result.breakdown.scaledInches, 18)
        XCTAssertEqual(result.breakdown.hillAdjustmentInches, -2)
        XCTAssertEqual(result.aimInches, 16)
        XCTAssertEqual(result.breakDirection, .rightToLeft)
        XCTAssertEqual(result.aimSide, .right)
        XCTAssertEqual(Format.aim(inches: result.aimInches, unit: .inches, side: result.aimSide).text, "16in R")
    }

    // Design pack 5a: 2.1% side slope is read as 2% in the working, still 16in R.
    func testDecimalSideSlopeRoundsToWholePercent() {
        let result = TourRead.read(feet: 15, slope: SlopeReading(uphillPercent: 1.2, sidePercent: 2.1))
        XCTAssertEqual(result.breakdown.slopePercent, 2)
        XCTAssertEqual(result.aimInches, 16)
    }

    func testOnePercentBreak() {
        XCTAssertEqual(TourRead.onePercentBreak(feet: 15), 9)   // 5 yd × 2 − 1
        XCTAssertEqual(TourRead.onePercentBreak(feet: 30), 19)  // 10 yd × 2 − 1
        XCTAssertEqual(TourRead.onePercentBreak(feet: 8), 4)    // 2.67 × 2 − 1 = 4.33
        XCTAssertEqual(TourRead.onePercentBreak(feet: 3), 1)    // minimum 1
        XCTAssertEqual(TourRead.onePercentBreak(feet: 1), 1)
    }

    func testDownhillAddsSlope() {
        XCTAssertEqual(TourRead.aimInches(feet: 20, slopePercent: 2, hill: .down), 26) // 12 × 2 + 2
    }

    func testFlatHasNoAdjustment() {
        XCTAssertEqual(TourRead.aimInches(feet: 12, slopePercent: 3, hill: .flat), 21) // 7 × 3
    }

    func testStraightPuttAimsCentre() {
        let result = TourRead.read(feet: 10, slope: SlopeReading(uphillPercent: 2, sidePercent: 0.3))
        XCTAssertEqual(result.breakDirection, .straight)
        XCTAssertEqual(result.aimInches, 0)
        XCTAssertEqual(result.aimSide, .centre)
    }

    func testAimNeverNegative() {
        XCTAssertEqual(TourRead.aimInches(feet: 3, slopePercent: 1, hill: .up), 0) // 1 × 1 − 1
    }

    func testGreenSpeedScalesAim() {
        XCTAssertEqual(TourRead.aimInches(feet: 15, slopePercent: 2, hill: .up, speed: .slow), 13)  // 16 × 0.8 = 12.8
        XCTAssertEqual(TourRead.aimInches(feet: 15, slopePercent: 2, hill: .up, speed: .medium), 16)
        XCTAssertEqual(TourRead.aimInches(feet: 15, slopePercent: 2, hill: .up, speed: .fast), 19)  // 16 × 1.2 = 19.2
    }

    func testLeftToRightAimsLeft() {
        let result = TourRead.read(feet: 12, slope: SlopeReading(uphillPercent: 0, sidePercent: -3))
        XCTAssertEqual(result.breakDirection, .leftToRight)
        XCTAssertEqual(result.aimSide, .left)
        XCTAssertEqual(result.aimInches, 21)
    }

    // Design examples: 15 ft at 1.2% uphill plays like 17 ft on a Medium green.
    func testPlaysLike() {
        XCTAssertEqual(TourRead.playsLikeFeet(feet: 15, uphillPercent: 1.2), 16.8, accuracy: 0.0001)
        XCTAssertEqual(Format.distance(feet: TourRead.playsLikeFeet(feet: 15, uphillPercent: 1.2), unit: .feet), "17 ft")
        XCTAssertEqual(TourRead.playsLikeFeet(feet: 10, uphillPercent: 2), 12, accuracy: 0.0001)
        XCTAssertEqual(TourRead.playsLikeFeet(feet: 20, uphillPercent: -2), 16, accuracy: 0.0001)
        XCTAssertEqual(TourRead.playsLikeFeet(feet: 10, uphillPercent: 2, speed: .fast), 12.4, accuracy: 0.0001)
        XCTAssertEqual(TourRead.playsLikeFeet(feet: 2, uphillPercent: -60), 1, accuracy: 0.0001) // floor of 1 ft
    }

    func testHillAndBreakThresholds() {
        XCTAssertEqual(Hill(uphillPercent: 0.4), .flat)
        XCTAssertEqual(Hill(uphillPercent: 0.5), .up)
        XCTAssertEqual(Hill(uphillPercent: -0.7), .down)
        XCTAssertEqual(BreakDirection(sidePercent: -0.49), .straight)
        XCTAssertEqual(BreakDirection(sidePercent: 0.5), .rightToLeft)
        XCTAssertEqual(BreakDirection(sidePercent: -1), .leftToRight)
    }

    func testGreenSpeedClampsAndNames() {
        XCTAssertEqual(GreenSpeed(stimp: 20).stimp, 14)
        XCTAssertEqual(GreenSpeed(stimp: 2).stimp, 6)
        XCTAssertEqual(GreenSpeed.medium.displayName, "Medium")
        XCTAssertEqual(GreenSpeed(stimp: 11).displayName, "Stimp 11")
        XCTAssertEqual(GreenSpeed.medium.breakFactor, 1)
        XCTAssertEqual(GreenSpeed.fast.breakFactor, 1.2, accuracy: 0.0001)
    }
}
