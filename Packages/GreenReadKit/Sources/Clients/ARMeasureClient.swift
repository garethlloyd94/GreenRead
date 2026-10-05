import ARKit
import Dependencies
import DependenciesMacros

/// Whether tap-to-measure can run. The AR session itself lives in the measure view.
@DependencyClient
public struct ARMeasureClient: Sendable {
    public var isSupported: @Sendable () -> Bool = { false }
}

extension ARMeasureClient: DependencyKey {
    public static var liveValue: Self {
        Self(isSupported: { ARWorldTrackingConfiguration.isSupported })
    }

    public static var previewValue: Self {
        Self(isSupported: { false })
    }

    public static let testValue = Self()
}
