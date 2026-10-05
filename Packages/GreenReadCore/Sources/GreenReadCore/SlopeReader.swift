import Foundation

/// One CoreMotion attitude sample, phone lying face up with its top edge toward the hole.
public struct AttitudeSample: Equatable, Sendable {
    /// Seconds, from any monotonic clock (CoreMotion's `timestamp`).
    public var time: TimeInterval
    /// Rotation about the phone's short axis; positive when the top edge is higher.
    public var pitch: Double
    /// Rotation about the phone's long axis; positive when the right edge is lower.
    public var roll: Double

    public init(time: TimeInterval, pitch: Double, roll: Double) {
        self.time = time
        self.pitch = pitch
        self.roll = roll
    }

    /// Uphill % toward the hole: tan(pitch) × 100.
    /// Side %: positive when the left side is low, so the ball breaks right to left.
    public var slope: SlopeReading {
        SlopeReading(uphillPercent: tan(pitch) * 100, sidePercent: -tan(roll) * 100)
    }

    /// Angle between the screen's normal and straight up, in radians.
    public var tilt: Double {
        acos(min(1, cos(pitch) * cos(roll)))
    }
}

/// Turns a stream of attitude samples into the Lay flat states:
/// not flat → flat (held still for `stillDuration`) → reading (averaging for `readDuration`) → done.
/// Any wobble or lift while settling or reading starts again from "flat".
public struct SlopeReader: Sendable {
    public enum Phase: Equatable, Sendable {
        /// Tilted more than `maxTilt`: orange, "Turn top edge to hole".
        case notFlat(live: SlopeReading)
        /// Flat but still settling: orange, Flat ✓, Aimed ↻.
        case flat(live: SlopeReading)
        /// Flat and still: green, "Reading…" with progress 0–1.
        case reading(progress: Double, live: SlopeReading)
        /// The averaged result.
        case done(SlopeReading)
    }

    public struct Configuration: Equatable, Sendable {
        /// Greens are rarely steeper than 5% (≈ 3°); anything over 6° isn't lying on the green.
        public var maxTilt = 6 * Double.pi / 180
        /// Pitch and roll must stay within this range (≈ 0.2°) to count as still.
        public var maxWobble = 0.0035
        public var stillDuration: TimeInterval = 1.0
        public var readDuration: TimeInterval = 1.0

        public init() {}
    }

    public let configuration: Configuration
    public private(set) var phase: Phase = .notFlat(live: SlopeReading(uphillPercent: 0, sidePercent: 0))

    private var window: [AttitudeSample] = []
    private var stillSince: TimeInterval?
    private var readingSamples: [AttitudeSample] = []

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Feeds one sample and returns the new phase. Once `.done`, further samples are ignored.
    @discardableResult
    public mutating func ingest(_ sample: AttitudeSample) -> Phase {
        if case .done = phase { return phase }

        guard sample.tilt <= configuration.maxTilt else {
            reset()
            phase = .notFlat(live: sample.slope)
            return phase
        }

        window.append(sample)
        window.removeAll { sample.time - $0.time > configuration.stillDuration }

        guard isStill(window) else {
            stillSince = nil
            readingSamples.removeAll()
            phase = .flat(live: sample.slope)
            return phase
        }

        let since = stillSince ?? window.first?.time ?? sample.time
        stillSince = since
        guard sample.time - since >= configuration.stillDuration else {
            phase = .flat(live: sample.slope)
            return phase
        }

        readingSamples.append(sample)
        let elapsed = sample.time - (readingSamples.first?.time ?? sample.time)
        if elapsed >= configuration.readDuration {
            phase = .done(Self.average(readingSamples))
        } else {
            phase = .reading(progress: elapsed / configuration.readDuration, live: sample.slope)
        }
        return phase
    }

    public mutating func reset() {
        window.removeAll()
        stillSince = nil
        readingSamples.removeAll()
    }

    private func isStill(_ samples: [AttitudeSample]) -> Bool {
        guard let first = samples.first else { return false }
        var minPitch = first.pitch, maxPitch = first.pitch
        var minRoll = first.roll, maxRoll = first.roll
        for sample in samples.dropFirst() {
            minPitch = min(minPitch, sample.pitch)
            maxPitch = max(maxPitch, sample.pitch)
            minRoll = min(minRoll, sample.roll)
            maxRoll = max(maxRoll, sample.roll)
        }
        return maxPitch - minPitch <= configuration.maxWobble && maxRoll - minRoll <= configuration.maxWobble
    }

    private static func average(_ samples: [AttitudeSample]) -> SlopeReading {
        let count = Double(max(1, samples.count))
        let pitch = samples.reduce(0) { $0 + $1.pitch } / count
        let roll = samples.reduce(0) { $0 + $1.roll } / count
        return AttitudeSample(time: 0, pitch: pitch, roll: roll).slope
    }
}
