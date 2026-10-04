import XCTest
@testable import GreenReadCore

final class FormatTests: XCTestCase {

    func testAimInInches() {
        XCTAssertEqual(Format.aim(inches: 16, unit: .inches, side: .right).text, "16in R")
        XCTAssertEqual(Format.aim(inches: 0, unit: .inches, side: .right).text, "0in")
    }

    // Cups: inches ÷ 4.25, rounded to the nearest half (prototype `fa`).
    func testAimInCups() {
        XCTAssertEqual(Format.aim(inches: 16, unit: .cups, side: .right).text, "4 cups R")   // 3.76 → 4
        XCTAssertEqual(Format.aim(inches: 4, unit: .cups).amount, "1 cup")                     // 0.94 → 1
        XCTAssertEqual(Format.aim(inches: 6, unit: .cups).amount, "1.5 cups")                  // 1.41 → 1.5
        XCTAssertEqual(Format.aim(inches: 12, unit: .cups).amount, "3 cups")                   // 2.82 → 3
    }

    // Balls: inches ÷ 1.68, rounded to a whole number.
    func testAimInBalls() {
        XCTAssertEqual(Format.aim(inches: 16, unit: .balls, side: .left).text, "10 balls L")  // 9.52 → 10
        XCTAssertEqual(Format.aim(inches: 2, unit: .balls).amount, "1 ball")                   // 1.19 → 1
    }

    func testSignedAim() {
        XCTAssertEqual(Format.signedAim(inches: -2, unit: .inches), "−2in")
        XCTAssertEqual(Format.signedAim(inches: 2, unit: .inches), "+2in")
        XCTAssertEqual(Format.signedAim(inches: 0, unit: .inches), "0in")
    }

    func testDistance() {
        XCTAssertEqual(Format.distance(feet: 15, unit: .feet), "15 ft")
        XCTAssertEqual(Format.distance(feet: 16.8, unit: .feet), "17 ft")
        XCTAssertEqual(Format.distance(feet: 15, unit: .metres), "4.6 m")   // 4.572
        XCTAssertEqual(Format.distance(feet: 10, unit: .metres), "3.0 m")
    }

    func testSlopeAndYards() {
        XCTAssertEqual(Format.slope(percent: 2.1), "2.1%")
        XCTAssertEqual(Format.slope(percent: -1.2), "1.2%")
        XCTAssertEqual(Format.yards(feet: 15), "5 yd")
        XCTAssertEqual(Format.yards(feet: 20), "6.7 yd")
    }
}
