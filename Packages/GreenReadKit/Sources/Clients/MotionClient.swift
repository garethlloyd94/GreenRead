import CoreMotion
import Dependencies
import DependenciesMacros
import Foundation
import GreenReadCore

/// Raw device attitude at 60 Hz. Features run `SlopeReader` over it inside their effect and
/// send only phase changes to the store.
@DependencyClient
public struct MotionClient: Sendable {
    public var attitudeUpdates: @Sendable () -> AsyncStream<AttitudeSample> = { .finished }
}

extension MotionClient: DependencyKey {
    public static var liveValue: Self {
        Self(
            attitudeUpdates: {
                AsyncStream { continuation in
                    let manager = MotionManagerBox()
                    manager.start { sample in continuation.yield(sample) }
                    continuation.onTermination = { _ in manager.stop() }
                }
            }
        )
    }

    /// A phone being picked up, laid on a 1.2% uphill, 2.1% right-to-left green, and held still.
    public static var previewValue: Self {
        Self(attitudeUpdates: { .scripted(uphill: 1.2, side: 2.1) })
    }

    public static let testValue = Self()
}

extension AsyncStream<AttitudeSample> {
    /// 0.8 s tilted, then flat and still at the given slope, at 60 Hz in real time.
    public static func scripted(uphill: Double, side: Double) -> Self {
        AsyncStream { continuation in
            let task = Task {
                let interval = 1.0 / 60
                var time = 0.0
                while !Task.isCancelled {
                    let isTilted = time < 0.8
                    continuation.yield(
                        AttitudeSample(
                            time: time,
                            pitch: isTilted ? 0.35 : atan(uphill / 100),
                            roll: isTilted ? -0.2 : -atan(side / 100)
                        )
                    )
                    time += interval
                    try? await Task.sleep(for: .seconds(interval))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Owns the `CMMotionManager` for one stream.
private final class MotionManagerBox: @unchecked Sendable {
    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    func start(_ handler: @escaping @Sendable (AttitudeSample) -> Void) {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { motion, _ in
            guard let motion else { return }
            handler(
                AttitudeSample(
                    time: motion.timestamp,
                    pitch: motion.attitude.pitch,
                    roll: motion.attitude.roll
                )
            )
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
