import AVFoundation
import CoreMotion
import Dependencies
import DependenciesMacros

public enum PermissionStatus: Equatable, Sendable {
    /// Never asked: show the primer (S6 / S7) before the system prompt.
    case notDetermined
    case authorized
    /// Denied or restricted: show the "Open Settings" state.
    case denied
}

/// Camera (Scan, tap-to-measure) and Motion & Fitness (Quick Read primer, Walk it off).
@DependencyClient
public struct PermissionsClient: Sendable {
    public var cameraStatus: @Sendable () -> PermissionStatus = { .notDetermined }
    public var requestCamera: @Sendable () async -> Bool = { false }
    public var motionStatus: @Sendable () -> PermissionStatus = { .notDetermined }
    public var requestMotion: @Sendable () async -> Bool = { false }
}

extension PermissionsClient: DependencyKey {
    public static var liveValue: Self {
        Self(
            cameraStatus: {
                switch AVCaptureDevice.authorizationStatus(for: .video) {
                case .notDetermined: .notDetermined
                case .authorized: .authorized
                default: .denied
                }
            },
            requestCamera: {
                await AVCaptureDevice.requestAccess(for: .video)
            },
            motionStatus: {
                // Nothing to ask for where Motion & Fitness doesn't exist (the Simulator).
                guard CMMotionActivityManager.isActivityAvailable() else { return .authorized }
                return switch CMMotionActivityManager.authorizationStatus() {
                case .notDetermined: .notDetermined
                case .authorized: .authorized
                default: .denied
                }
            },
            requestMotion: {
                guard CMMotionActivityManager.isActivityAvailable() else { return true }
                // Motion & Fitness has no request API: the first activity query shows the prompt.
                return await withCheckedContinuation { continuation in
                    let manager = CMMotionActivityManager()
                    let now = Date()
                    manager.queryActivityStarting(from: now, to: now, to: .main) { _, _ in
                        continuation.resume(returning: CMMotionActivityManager.authorizationStatus() == .authorized)
                        _ = manager
                    }
                }
            }
        )
    }

    public static var previewValue: Self {
        Self(
            cameraStatus: { .authorized },
            requestCamera: { true },
            motionStatus: { .authorized },
            requestMotion: { true }
        )
    }

    public static let testValue = Self()
}
