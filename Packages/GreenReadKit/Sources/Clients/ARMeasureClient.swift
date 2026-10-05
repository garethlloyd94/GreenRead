import ARKit
import Dependencies
import DependenciesMacros

/// Whether AR can run. The AR sessions themselves live in the measure and scan views.
@DependencyClient
public struct ARMeasureClient: Sendable {
    /// World tracking, for tap-to-measure (any recent iPhone).
    public var isSupported: @Sendable () -> Bool = { false }
    /// Scene reconstruction, for Scan (LiDAR iPhones).
    public var supportsLiDAR: @Sendable () -> Bool = { false }
}

extension ARMeasureClient: DependencyKey {
    public static var liveValue: Self {
        Self(
            isSupported: { ARWorldTrackingConfiguration.isSupported },
            supportsLiDAR: { ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) }
        )
    }

    public static var previewValue: Self {
        Self(isSupported: { false }, supportsLiDAR: { false })
    }

    public static let testValue = Self()
}
