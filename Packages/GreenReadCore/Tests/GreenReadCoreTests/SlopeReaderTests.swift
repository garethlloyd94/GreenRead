import Foundation
import Testing
@testable import GreenReadCore

struct SlopeReaderTests {

    /// Pitch for a given uphill %, roll for a given side % (positive = left side low).
    private func sample(_ time: TimeInterval, uphill: Double, side: Double) -> AttitudeSample {
        AttitudeSample(time: time, pitch: atan(uphill / 100), roll: -atan(side / 100))
    }

    private func feed(_ reader: inout SlopeReader, from start: TimeInterval, to end: TimeInterval, uphill: Double, side: Double) -> SlopeReader.Phase {
        var time = start
        var phase = reader.phase
        while time <= end + 0.000_1 {
            phase = reader.ingest(sample(time, uphill: uphill, side: side))
            time += 1.0 / 60
        }
        return phase
    }

    @Test func signConventions() {
        let reading = sample(0, uphill: 1.2, side: 2.1).slope
        #expect(abs(reading.uphillPercent - 1.2) < 0.0001)
        #expect(abs(reading.sidePercent - 2.1) < 0.0001)
        #expect(reading.hill == .up)
        #expect(reading.breakDirection == .rightToLeft)

        let downhillLeftToRight = AttitudeSample(time: 0, pitch: -0.02, roll: 0.03).slope
        #expect(downhillLeftToRight.hill == .down)
        #expect(downhillLeftToRight.breakDirection == .leftToRight)
    }

    @Test func tiltedPhoneIsNotFlat() {
        var reader = SlopeReader()
        let phase = reader.ingest(AttitudeSample(time: 0, pitch: 0.3, roll: 0))
        guard case .notFlat = phase else {
            Issue.record("Expected notFlat, got \(phase)")
            return
        }
    }

    @Test func stillPhoneSettlesThenReadsThenFinishes() {
        var reader = SlopeReader()

        let settling = feed(&reader, from: 0, to: 0.9, uphill: 1.2, side: 2.1)
        guard case .flat = settling else {
            Issue.record("Expected flat while settling, got \(settling)")
            return
        }

        let reading = feed(&reader, from: 0.9 + 1.0 / 60, to: 1.5, uphill: 1.2, side: 2.1)
        guard case let .reading(progress, _) = reading else {
            Issue.record("Expected reading, got \(reading)")
            return
        }
        #expect(progress > 0 && progress < 1)

        let done = feed(&reader, from: 1.5 + 1.0 / 60, to: 2.1, uphill: 1.2, side: 2.1)
        guard case let .done(result) = done else {
            Issue.record("Expected done, got \(done)")
            return
        }
        #expect(abs(result.uphillPercent - 1.2) < 0.001)
        #expect(abs(result.sidePercent - 2.1) < 0.001)
    }

    @Test func wobbleRestartsSettling() {
        var reader = SlopeReader()
        _ = feed(&reader, from: 0, to: 0.8, uphill: 1, side: 1)
        let wobble = reader.ingest(sample(0.82, uphill: 1.6, side: 1))
        guard case .flat = wobble else {
            Issue.record("Expected flat after wobble, got \(wobble)")
            return
        }
        // Needs a full second of stillness again before reading.
        let stillSettling = feed(&reader, from: 0.84, to: 1.7, uphill: 1.6, side: 1)
        guard case .flat = stillSettling else {
            Issue.record("Expected flat, got \(stillSettling)")
            return
        }
    }

    @Test func liftingThePhoneResets() {
        var reader = SlopeReader()
        _ = feed(&reader, from: 0, to: 1.4, uphill: 1, side: 1)
        _ = reader.ingest(AttitudeSample(time: 1.42, pitch: 0.5, roll: 0))
        let phase = feed(&reader, from: 1.44, to: 2.2, uphill: 1, side: 1)
        guard case .flat = phase else {
            Issue.record("Expected flat after lift, got \(phase)")
            return
        }
    }

    @Test func doneIgnoresLaterSamples() {
        var reader = SlopeReader()
        let done = feed(&reader, from: 0, to: 2.1, uphill: 2, side: -1)
        let after = reader.ingest(AttitudeSample(time: 3, pitch: 0.5, roll: 0.5))
        #expect(done == after)
    }
}
