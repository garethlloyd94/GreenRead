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

    private enum CodingKeys: String, CodingKey {
        case distanceUnit, aimUnit, defaultSpeed, paceLengthFeet, hapticsOn, soundsOn
    }

    /// Missing or unreadable fields fall back to their defaults instead of failing the whole file,
    /// so adding a setting later doesn't reset everyone's settings. Pace length is clamped.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        distanceUnit = (try? container.decodeIfPresent(DistanceUnit.self, forKey: .distanceUnit)) ?? defaults.distanceUnit
        aimUnit = (try? container.decodeIfPresent(AimUnit.self, forKey: .aimUnit)) ?? defaults.aimUnit
        defaultSpeed = (try? container.decodeIfPresent(GreenSpeed.self, forKey: .defaultSpeed)) ?? defaults.defaultSpeed
        let paceLength = (try? container.decodeIfPresent(Double.self, forKey: .paceLengthFeet)) ?? defaults.paceLengthFeet
        paceLengthFeet = min(max(paceLength, Self.paceLengthRange.lowerBound), Self.paceLengthRange.upperBound)
        hapticsOn = (try? container.decodeIfPresent(Bool.self, forKey: .hapticsOn)) ?? defaults.hapticsOn
        soundsOn = (try? container.decodeIfPresent(Bool.self, forKey: .soundsOn)) ?? defaults.soundsOn
    }
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
