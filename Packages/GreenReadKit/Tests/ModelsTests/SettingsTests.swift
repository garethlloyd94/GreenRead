import Foundation
import GreenReadCore
import Testing

@testable import Models

struct SettingsTests {
    @Test func roundTrips() throws {
        var settings = AppSettings()
        settings.aimUnit = .cups
        settings.defaultSpeed = .fast
        settings.paceLengthFeet = 3
        settings.hapticsOn = false

        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    // A settings file written before a field existed keeps its other values.
    @Test func missingFieldsUseDefaults() throws {
        let decoded = try decode(#"{"aimUnit":"balls"}"#)
        var expected = AppSettings()
        expected.aimUnit = .balls
        #expect(decoded == expected)
    }

    @Test func unreadableFieldsUseDefaults() throws {
        let decoded = try decode(#"{"aimUnit":"furlongs","distanceUnit":"metres","hapticsOn":"yes"}"#)
        var expected = AppSettings()
        expected.distanceUnit = .metres
        #expect(decoded == expected)
    }

    @Test func outOfRangeValuesAreClamped() throws {
        let decoded = try decode(#"{"paceLengthFeet":10,"defaultSpeed":{"stimp":20}}"#)
        #expect(decoded.paceLengthFeet == AppSettings.paceLengthRange.upperBound)
        #expect(decoded.defaultSpeed.stimp == GreenSpeed.stimpRange.upperBound)
        #expect(try decode(#"{"paceLengthFeet":0.5}"#).paceLengthFeet == AppSettings.paceLengthRange.lowerBound)
    }

    private func decode(_ json: String) throws -> AppSettings {
        try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    }
}
