import Foundation
import GreenReadCore
import SwiftData

/// User settings, stored on the device. There is only ever one row; use `AppSettings.current(in:)`.
@Model
final class AppSettings {
    var distanceUnitRaw: String
    var aimUnitRaw: String
    /// Default green speed for Quick Read and the Scan speed sheet.
    var defaultStimp: Double
    /// Pace length for "Walk it off", in feet (2.0–3.5).
    var paceLengthFeet: Double
    var hapticsOn: Bool
    var soundsOn: Bool

    init(
        distanceUnit: DistanceUnit = .feet,
        aimUnit: AimUnit = .inches,
        defaultSpeed: GreenSpeed = .medium,
        paceLengthFeet: Double = AppSettings.defaultPaceLengthFeet,
        hapticsOn: Bool = true,
        soundsOn: Bool = true
    ) {
        self.distanceUnitRaw = distanceUnit.rawValue
        self.aimUnitRaw = aimUnit.rawValue
        self.defaultStimp = defaultSpeed.stimp
        self.paceLengthFeet = paceLengthFeet
        self.hapticsOn = hapticsOn
        self.soundsOn = soundsOn
    }

    static let defaultPaceLengthFeet = 2.7
    static let paceLengthRange: ClosedRange<Double> = 2.0...3.5

    var distanceUnit: DistanceUnit {
        get { DistanceUnit(rawValue: distanceUnitRaw) ?? .feet }
        set { distanceUnitRaw = newValue.rawValue }
    }

    var aimUnit: AimUnit {
        get { AimUnit(rawValue: aimUnitRaw) ?? .inches }
        set { aimUnitRaw = newValue.rawValue }
    }

    var defaultSpeed: GreenSpeed {
        get { GreenSpeed(stimp: defaultStimp) }
        set { defaultStimp = newValue.stimp }
    }

    /// Returns the stored settings, creating them with defaults on first launch.
    @MainActor
    static func current(in context: ModelContext) -> AppSettings {
        if let existing = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }
}
