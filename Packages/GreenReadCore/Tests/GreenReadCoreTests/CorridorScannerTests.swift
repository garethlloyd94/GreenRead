import Foundation
import Testing
@testable import GreenReadCore

struct CorridorScannerTests {
    /// Ball at the origin, hole 4 m away along −z (straight ahead in ARKit).
    private let ball = Point3(x: 0, y: 0, z: 0)
    private let hole = Point3(x: 0, y: 0, z: -4)

    /// A dense grid over the corridor on a plane rising `uphill` % toward the hole and
    /// `side` % toward the right (so the left is low).
    private func plane(
        _ scanner: CorridorScanner,
        uphill: Double,
        side: Double,
        vRange: ClosedRange<Double> = -0.5...0.5,
        uRange: ClosedRange<Double>? = nil
    ) -> [Point3] {
        var points: [Point3] = []
        let us = uRange ?? (-0.3)...(scanner.length + 0.3)
        var u = us.lowerBound
        while u < us.upperBound {
            var v = vRange.lowerBound
            while v < vRange.upperBound {
                let height = u * uphill / 100 + v * side / 100
                points.append(scanner.world(u: u, v: v, y: height))
                v += 0.03
            }
            u += 0.03
        }
        return points
    }

    @Test func corridorAxes() {
        let scanner = CorridorScanner(ball: ball, hole: hole)
        #expect(abs(scanner.length - 4) < 1e-9)
        let (u, v) = scanner.corridor(Point3(x: 0.2, y: 0, z: -1))
        #expect(abs(u - 1) < 1e-9)
        // Looking from ball to hole along −z, +x is to the right.
        #expect(abs(v - 0.2) < 1e-9)
    }

    @Test func fullCoverageFitsThePlane() throws {
        var scanner = CorridorScanner(ball: ball, hole: hole)
        scanner.update(anchor: "a", vertices: plane(scanner, uphill: 1.5, side: 2.5))
        let progress = scanner.progress
        #expect(progress.coverage > CorridorScanner.completeCoverage)
        let slope = try #require(progress.slope)
        #expect(abs(slope.uphillPercent - 1.5) < 0.05)
        #expect(abs(slope.sidePercent - 2.5) < 0.05)
        #expect(slope.breakDirection == .rightToLeft)
        #expect(slope.hill == .up)
    }

    @Test func updatingAnAnchorReplacesItsContribution() {
        var scanner = CorridorScanner(ball: ball, hole: hole)
        scanner.update(anchor: "a", vertices: plane(scanner, uphill: 0, side: 0))
        let full = scanner.progress.coverage
        scanner.update(anchor: "a", vertices: plane(scanner, uphill: 0, side: 0, vRange: 0...0.5))
        #expect(scanner.progress.coverage < full * 0.6)
        scanner.remove(anchor: "a")
        #expect(scanner.progress.coverage == 0)
    }

    @Test func promptsForTheMissingSide() {
        var scanner = CorridorScanner(ball: ball, hole: hole)
        scanner.update(anchor: "right", vertices: plane(scanner, uphill: 0, side: 0, vRange: 0...0.5))
        #expect(scanner.progress.prompt == .coverLeft)

        var other = CorridorScanner(ball: ball, hole: hole)
        other.update(anchor: "left", vertices: plane(other, uphill: 0, side: 0, vRange: -0.5...0))
        #expect(other.progress.prompt == .coverRight)
    }

    @Test func promptsForAGapBehind() {
        var scanner = CorridorScanner(ball: ball, hole: hole)
        scanner.update(anchor: "far", vertices: plane(scanner, uphill: 0, side: 0, uRange: 2...4.3))
        #expect(scanner.progress.prompt == .gapBehind)
    }

    @Test func tooLittleSurfaceHasNoFit() {
        var scanner = CorridorScanner(ball: ball, hole: hole)
        scanner.update(anchor: "a", vertices: [Point3(x: 0, y: 0, z: -1)])
        #expect(scanner.progress.slope == nil)
        #expect(scanner.progress.prompt == .walkToHole)
    }

    @Test func breakLineStartsAtBallEndsAtHoleAndBendsToTheAimSide() {
        let points = BreakLine.points(length: 4, aimMetres: 0.4)
        #expect(points.first!.u == 0 && points.first!.v == 0)
        #expect(abs(points.last!.u - 4) < 1e-9 && abs(points.last!.v) < 1e-9)
        #expect(points.allSatisfy { $0.v >= 0 })
        #expect(points.map(\.v).max()! > 0.1)

        let result = TourRead.read(feet: 15, slope: SlopeReading(uphillPercent: 1.2, sidePercent: 2))
        #expect(abs(BreakLine.aimMetres(result) - 16 * 0.0254) < 1e-9)
    }
}
