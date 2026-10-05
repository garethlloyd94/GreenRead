import ComposableArchitecture
import DependenciesTestSupport
import GreenReadCore
import Models
import Testing

@testable import SettingsFeature

@MainActor
struct SettingsFeatureTests {
    @Test(.dependencies) func greenSpeedStepsByOneStimpWithinRange() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }

        await store.send(.greenSpeedPlusTapped) {
            $0.$settings.withLock { $0.defaultSpeed = GreenSpeed(stimp: 11) }
        }
        await store.send(.greenSpeedMinusTapped) {
            $0.$settings.withLock { $0.defaultSpeed = .medium }
        }

        store.state.$settings.withLock { $0.defaultSpeed = GreenSpeed(stimp: 14) }
        await store.send(.greenSpeedPlusTapped)
    }

    @Test(.dependencies) func paceLengthStepsByATenthWithinRange() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }

        await store.send(.paceLengthPlusTapped) {
            $0.$settings.withLock { $0.paceLengthFeet = 2.8 }
        }
        await store.send(.paceLengthMinusTapped) {
            $0.$settings.withLock { $0.paceLengthFeet = 2.7 }
        }

        store.state.$settings.withLock { $0.paceLengthFeet = 2.0 }
        await store.send(.paceLengthMinusTapped)
    }

    @Test func settingsFormatAimAndDistanceInTheChosenUnits() {
        var settings = AppSettings()
        #expect(settings.aim(inches: 16, side: .right).text == "16in R")
        #expect(settings.distance(feet: 15) == "15 ft")
        #expect(settings.paceLengthLabel == "2.7 ft")

        settings.aimUnit = .cups
        settings.distanceUnit = .metres
        #expect(settings.aim(inches: 16, side: .right).text == "4 cups R")
        #expect(settings.distance(feet: 15) == "4.6 m")
        #expect(settings.paceLengthLabel == "0.82 m")
    }
}
