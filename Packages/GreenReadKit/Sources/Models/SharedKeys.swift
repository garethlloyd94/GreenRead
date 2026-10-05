import Foundation
import GreenReadCore
import Sharing

/// User settings, stored on the device as JSON.
public struct AppSettings: Codable, Equatable, Sendable {
    public var distanceUnit: DistanceUnit = .feet
    public var aimUnit: AimUnit = .inches
    /// Default green speed for Quick Read and the Scan speed sheet.
    public var defaultSpeed: GreenSpeed = .medium
    /// Pace length for "Walk it off", in feet.
    public var paceLengthFeet = AppSettings.defaultPaceLengthFeet
    public var hapticsOn = true
    public var soundsOn = true

    public static let defaultPaceLengthFeet = 2.7
    public static let paceLengthRange: ClosedRange<Double> = 2.0...3.5

    public init() {}
}

public enum Tempo {
    public static let bpmRange: ClosedRange<Int> = 60...100
    public static let defaultBPM = 76
}

extension SharedKey where Self == FileStorageKey<AppSettings>.Default {
    public static var appSettings: Self {
        Self[
            .fileStorage(.applicationSupportDirectory.appending(component: "settings.json")),
            default: AppSettings()
        ]
    }
}

extension SharedKey where Self == AppStorageKey<Bool>.Default {
    public static var hasSeenOnboarding: Self {
        Self[.appStorage("hasSeenOnboarding"), default: false]
    }
}

extension SharedKey where Self == AppStorageKey<Int>.Default {
    /// Metronome tempo; also shown on the Home Tempo tile.
    public static var tempoBPM: Self {
        Self[.appStorage("tempoBPM"), default: Tempo.defaultBPM]
    }
}
