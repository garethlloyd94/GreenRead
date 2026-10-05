import Clients
import ComposableArchitecture
import CustomDump
import DependenciesTestSupport
import Foundation
import GreenReadCore
import Models
import SQLiteData
import Testing

@testable import QuickReadFeature

@Suite(
    .dependencies {
        $0.date.now = Date(timeIntervalSince1970: 1_791_000_000)
        $0.uuid = .incrementing
        try $0.bootstrapDatabase()
    }
)
@MainActor
struct QuickReadFeatureTests {

    // MARK: Motion primer (S7)

    @Test func firstUseShowsPrimerThenAllowGoesToMeasure() async {
        let store = TestStore(initialState: QuickReadFeature.State()) {
            QuickReadFeature()
        } withDependencies: {
            $0[PermissionsClient.self].motionStatus = { .notDetermined }
            $0[PermissionsClient.self].requestMotion = { true }
        }

        await store.send(.task) {
            $0.hasCheckedPermission = true
            $0.primer = MotionPrimer.State()
        }
        await store.send(\.primer.allowButtonTapped)
        await store.receive(\.primer.motionPermissionResponse)
        await store.receive(\.primer.delegate.granted) {
            $0.primer = nil
        }
    }

    @Test func declinedPermissionShowsOpenSettings() async {
        let store = TestStore(initialState: QuickReadFeature.State()) {
            QuickReadFeature()
        } withDependencies: {
            $0[PermissionsClient.self].motionStatus = { .notDetermined }
            $0[PermissionsClient.self].requestMotion = { false }
        }

        await store.send(.task) {
            $0.hasCheckedPermission = true
            $0.primer = MotionPrimer.State()
        }
        await store.send(\.primer.allowButtonTapped)
        await store.receive(\.primer.motionPermissionResponse) {
            $0.primer?.isDenied = true
        }
    }

    @Test func deniedEarlierOpensOnSettingsStateAndNotNowCloses() async {
        let openedURL = LockIsolated<URL?>(nil)
        let store = TestStore(initialState: QuickReadFeature.State()) {
            QuickReadFeature()
        } withDependencies: {
            $0[PermissionsClient.self].motionStatus = { .denied }
            $0.openURL = OpenURLEffect { url in
                openedURL.setValue(url)
                return true
            }
        }

        await store.send(.task) {
            $0.hasCheckedPermission = true
            $0.primer = MotionPrimer.State(isDenied: true)
        }
        await store.send(\.primer.openSettingsButtonTapped)
        #expect(openedURL.value != nil)
        await store.send(\.primer.notNowButtonTapped)
        await store.receive(\.primer.delegate.notNow)
        await store.receive(\.delegate.close)
    }

    @Test func authorisedSkipsPrimer() async {
        let store = TestStore(initialState: QuickReadFeature.State()) {
            QuickReadFeature()
        } withDependencies: {
            $0[PermissionsClient.self].motionStatus = { .authorized }
        }

        await store.send(.task) {
            $0.hasCheckedPermission = true
        }
    }

    // MARK: Measure

    @Test func manualDistanceStaysWithin3To60Feet() async {
        var state = Measure.State()
        state.method = .manual
        state.manualFeet = 59
        let store = TestStore(initialState: state) { Measure() }

        await store.send(.distancePlusTapped) { $0.manualFeet = 60 }
        await store.send(.distancePlusTapped)

        state.manualFeet = 4
        let short = TestStore(initialState: state) { Measure() }
        await short.send(.distanceMinusTapped) { $0.manualFeet = 3 }
        await short.send(.distanceMinusTapped)
    }

    @Test func cameraTapsMeasureHorizontalDistance() async {
        let store = TestStore(initialState: Measure.State()) { Measure() }

        await store.send(.arPointPlaced(SIMD3(0, 0, 0))) {
            $0.points = [SIMD3(0, 0, 0)]
        }
        #expect(store.state.feet == nil)
        // 4.572 m across the green and 10 cm up: 15 ft, height ignored.
        await store.send(.arPointPlaced(SIMD3(0, 0.1, -4.572))) {
            $0.points.append(SIMD3(0, 0.1, -4.572))
        }
        #expect(abs((store.state.feet ?? 0) - 15) < 0.001)

        await store.send(.arPointPlaced(SIMD3(1, 0, 1)))
        await store.send(.undoTapped) {
            $0.points = [SIMD3(0, 0, 0)]
        }
    }

    @Test func noAROrDeniedCameraFallsBackToManual() async {
        let store = TestStore(initialState: Measure.State()) {
            Measure()
        } withDependencies: {
            $0[ARMeasureClient.self].isSupported = { true }
            $0[PedometerClient.self].isAvailable = { true }
            $0[PermissionsClient.self].cameraStatus = { .notDetermined }
            $0[PermissionsClient.self].requestCamera = { false }
        }

        await store.send(.task)
        await store.receive(\.cameraPermissionResponse) {
            $0.isCameraAvailable = false
            $0.method = .manual
        }

        let unsupported = TestStore(initialState: Measure.State()) {
            Measure()
        } withDependencies: {
            $0[ARMeasureClient.self].isSupported = { false }
            $0[PedometerClient.self].isAvailable = { false }
        }
        await unsupported.send(.task) {
            $0.isCameraAvailable = false
            $0.isPedometerAvailable = false
            $0.method = .manual
        }
    }

    @Test func walkItOffUsesPaceLength() async {
        let store = TestStore(initialState: Measure.State()) {
            Measure()
        } withDependencies: {
            $0[PedometerClient.self].steps = {
                AsyncThrowingStream { continuation in
                    continuation.yield(1)
                    continuation.yield(6)
                    continuation.finish()
                }
            }
        }

        await store.send(.walkItOffTapped) {
            $0.method = .walk
        }
        await store.receive(\.walkStepsUpdated) { $0.walkSteps = 1 }
        await store.receive(\.walkStepsUpdated) { $0.walkSteps = 6 }
        #expect(abs((store.state.feet ?? 0) - 6 * 2.7) < 0.0001)

        await store.send(.nextButtonTapped)
        await store.receive(\.delegate.measured)
    }

    // MARK: Lay flat

    @Test func layFlatReadsTheSlopeFromAStillPhone() async {
        let store = TestStore(initialState: LayFlat.State()) {
            LayFlat()
        } withDependencies: {
            $0[MotionClient.self].attitudeUpdates = { Self.samples(uphill: 1.2, side: 2.1) }
        }
        store.exhaustivity = .off

        await store.send(.task)
        await store.receive(\.delegate.finished, timeout: .seconds(5))
        guard case let .done(reading) = store.state.phase else {
            Issue.record("Expected done, got \(store.state.phase)")
            return
        }
        #expect(abs(reading.uphillPercent - 1.2) < 0.001)
        #expect(abs(reading.sidePercent - 2.1) < 0.001)
    }

    // MARK: Read flow

    @Test func readFlowMeasuresReadsAndSaves() async throws {
        var measure = Measure.State()
        measure.method = .manual
        var state = ReadFlow.State()
        state.step = .measure(measure)
        let store = TestStore(initialState: state) {
            ReadFlow()
        } withDependencies: {
            $0[MotionClient.self].attitudeUpdates = { Self.samples(uphill: 1.2, side: 2) }
        }

        await store.send(\.step.measure.nextButtonTapped)
        await store.receive(\.step.measure.delegate.measured) {
            $0.feet = 15
            $0.step = .layFlat(LayFlat.State())
        }

        store.exhaustivity = .off
        await store.send(\.step.layFlat.task)
        await store.receive(\.step.layFlat.delegate.finished, timeout: .seconds(5))
        store.exhaustivity = .on

        guard let result = store.state.step.result else {
            Issue.record("Expected the result step")
            return
        }
        // README example: 15 ft, 2% R→L, uphill, Medium → 16in R.
        #expect(result.result.aimInches == 16)
        #expect(result.result.aimSide == .right)
        #expect(result.settings.aim(inches: 16, side: .right).text == "16in R")

        await store.send(\.step.result.saveButtonTapped) {
            $0.step.modify(\.result) { $0.isSaved = true }
        }
        await store.finish()

        @Dependency(\.defaultDatabase) var database
        let saved = try await database.read { db in try SavedRead.all.fetchAll(db) }
        #expect(saved.count == 1)
        #expect(saved.first?.aimInches == 16)
        #expect(saved.first?.source == .quickRead)

        await store.send(\.step.result.newReadButtonTapped)
        await store.receive(\.step.result.delegate.newRead) {
            $0.feet = nil
            $0.step = .measure(Measure.State())
        }
    }

    @Test func workingLinesShowEachStep() {
        let breakdown = TourRead.breakdown(feet: 15, slopePercent: 2, hill: .up, speed: .fast)
        let lines = workingLines(breakdown, unit: .inches).map { "\($0.label) = \($0.value)" }
        expectNoDifference(
            lines,
            [
                "5 yd × 2 − 1 = 9in @1%",
                "× 2% slope = 18in",
                "uphill adj. = −2in",
                "fast green = × 1.2",
            ]
        )
    }

    /// Tilted for a moment, then 2.2 s flat and still, as a finite stream.
    private static func samples(uphill: Double, side: Double) -> AsyncStream<AttitudeSample> {
        AsyncStream { continuation in
            var time = 0.0
            while time < 0.3 {
                continuation.yield(AttitudeSample(time: time, pitch: 0.4, roll: 0.1))
                time += 1.0 / 60
            }
            while time < 2.6 {
                continuation.yield(AttitudeSample(time: time, pitch: atan(uphill / 100), roll: -atan(side / 100)))
                time += 1.0 / 60
            }
            continuation.finish()
        }
    }
}
