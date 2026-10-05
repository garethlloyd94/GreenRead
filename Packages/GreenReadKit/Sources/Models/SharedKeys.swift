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

    /// Aim in the chosen aim unit: "16in R", "4 cups R", "10 balls L".
    public func aim(inches: Int, side: AimSide = .centre) -> AimDisplay {
        Format.aim(inches: inches, unit: aimUnit, side: side)
    }

    /// Distance in the chosen unit: "15 ft" or "4.6 m".
    public func distance(feet: Double) -> String {
        Format.distance(feet: feet, unit: distanceUnit)
    }

    /// Pace length in the chosen unit: "2.7 ft" or "0.82 m".
    public var paceLengthLabel: String {
        switch distanceUnit {
        case .feet: String(format: "%.1f ft", paceLengthFeet)
        case .metres: String(format: "%.2f m", paceLengthFeet * DistanceUnit.metresPerFoot)
        }
    }

    public static let paceLengthStep = 0.1
    public static let stimpStep = 1.0

    /// Steps the pace length by ±0.1 ft, within 2.0–3.5 ft.
    public mutating func stepPaceLength(by steps: Int) {
        let next = ((paceLengthFeet + Double(steps) * Self.paceLengthStep) * 10).rounded() / 10
        paceLengthFeet = min(max(next, Self.paceLengthRange.lowerBound), Self.paceLengthRange.upperBound)
    }

    /// Steps the default green speed by ±1 Stimp, within 6–14.
    public mutating func stepDefaultSpeed(by steps: Int) {
        defaultSpeed = GreenSpeed(stimp: defaultSpeed.stimp + Double(steps) * Self.stimpStep)
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
