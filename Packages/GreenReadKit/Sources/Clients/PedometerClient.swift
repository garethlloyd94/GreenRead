import CoreMotion
import Dependencies
import DependenciesMacros
import Foundation

/// Step counts for "Walk it off", from when the stream starts.
@DependencyClient
public struct PedometerClient: Sendable {
    public var isAvailable: @Sendable () -> Bool = { false }
    public var steps: @Sendable () -> AsyncThrowingStream<Int, any Error> = { .finished() }
}

extension PedometerClient: DependencyKey {
    public static var liveValue: Self {
        Self(
            isAvailable: { CMPedometer.isStepCountingAvailable() },
            steps: {
                AsyncThrowingStream { continuation in
                    let pedometer = PedometerBox()
                    pedometer.start { result in
                        switch result {
                        case let .success(steps): continuation.yield(steps)
                        case let .failure(error): continuation.finish(throwing: error)
                        }
                    }
                    continuation.onTermination = { _ in pedometer.stop() }
                }
            }
        )
    }

    /// One step every 0.6 s.
    public static var previewValue: Self {
        Self(
            isAvailable: { true },
            steps: {
                AsyncThrowingStream { continuation in
                    let task = Task {
                        var steps = 0
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .seconds(0.6))
                            steps += 1
                            continuation.yield(steps)
                        }
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            }
        )
    }

    public static let testValue = Self()
}

private final class PedometerBox: @unchecked Sendable {
    private let pedometer = CMPedometer()

    func start(_ handler: @escaping @Sendable (Result<Int, any Error>) -> Void) {
        pedometer.startUpdates(from: Date()) { data, error in
            if let error {
                handler(.failure(error))
            } else if let data {
                handler(.success(data.numberOfSteps.intValue))
            }
        }
    }

    func stop() {
        pedometer.stopUpdates()
    }
}
