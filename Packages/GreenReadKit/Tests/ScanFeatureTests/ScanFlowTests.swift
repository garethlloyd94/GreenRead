import Clients
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import GreenReadCore
import Models
import SQLiteData
import Testing

@testable import ScanFeature

@Suite(
    .dependencies {
        $0.date.now = Date(timeIntervalSince1970: 1_791_000_000)
        $0.uuid = .incrementing
        try $0.bootstrapDatabase()
    }
)
@MainActor
struct ScanFlowTests {
    private let slope = SlopeReading(uphillPercent: 1.2, sidePercent: 2)

    @Test func noLiDARShowsS3AndRoutesToQuickRead() async {
        let store = TestStore(initialState: ScanFlow.State()) {
            ScanFlow()
        } withDependencies: {
            $0[ARMeasureClient.self].supportsLiDAR = { false }
        }

        await store.send(.task) { $0.step = .noLiDAR }
        await store.send(.useQuickReadButtonTapped)
        await store.receive(\.delegate.switchToQuickRead)
    }

    @Test func cameraPrimerAllowsThenMarks() async {
        let store = TestStore(initialState: ScanFlow.State()) {
            ScanFlow()
        } withDependencies: {
            $0[ARMeasureClient.self].supportsLiDAR = { true }
            $0[PermissionsClient.self].cameraStatus = { .notDetermined }
            $0[PermissionsClient.self].requestCamera = { true }
        }

        await store.send(.task) { $0.step = .cameraPrimer(isDenied: false) }
        await store.send(.allowCameraButtonTapped)
        await store.receive(\.cameraPermissionResponse) { $0.step = .mark }
    }

    @Test func deniedCameraShowsOpenSettings() async {
        let store = TestStore(initialState: ScanFlow.State()) {
            ScanFlow()
        } withDependencies: {
            $0[ARMeasureClient.self].supportsLiDAR = { true }
            $0[PermissionsClient.self].cameraStatus = { .notDetermined }
            $0[PermissionsClient.self].requestCamera = { false }
        }

        await store.send(.task) { $0.step = .cameraPrimer(isDenied: false) }
        await store.send(.allowCameraButtonTapped)
        await store.receive(\.cameraPermissionResponse) { $0.step = .cameraPrimer(isDenied: true) }
    }

    @Test func markScanChooseSpeedShowLineAndSave() async throws {
        var state = ScanFlow.State()
        state.step = .mark
        let store = TestStore(initialState: state) { ScanFlow() }

        // Can't start until both are marked.
        await store.send(.startScanButtonTapped)
        await store.send(.arPointPlaced(SIMD3(0, 0, 0))) { $0.points = [SIMD3(0, 0, 0)] }
        await store.send(.arPointPlaced(SIMD3(0, 0.05, -4.572))) { $0.points.append(SIMD3(0, 0.05, -4.572)) }
        #expect(abs((store.state.feet ?? 0) - 15) < 0.001)
        await store.send(.startScanButtonTapped) { $0.step = .scanning }

        let partial = ScanProgress(coverage: 0.5, prompt: .coverLeft, slope: slope)
        await store.send(.scanProgressed(partial)) { $0.progress = partial }

        // Auto-finishes at 95% and asks for green speed (defaults to Settings: Medium).
        let complete = ScanProgress(coverage: 0.96, prompt: .walkToHole, slope: slope)
        await store.send(.scanProgressed(complete)) {
            $0.progress = complete
            $0.slope = self.slope
            $0.greenSpeed = GreenSpeedPicker.State(speed: .medium)
        }
        await store.send(\.greenSpeed.presetTapped, .fast) { $0.greenSpeed?.speed = .fast }
        await store.send(\.greenSpeed.showLineButtonTapped)
        await store.receive(\.greenSpeed.delegate.showLine) {
            $0.speed = .fast
            $0.greenSpeed = nil
            $0.step = .result
        }
        // Q2: 15 ft, 2% R→L, uphill → 16in, ×1.2 on a fast green → 19in R.
        #expect(store.state.result?.aimInches == 19)
        #expect(store.state.result?.aimSide == .right)

        await store.send(.saveButtonTapped) { $0.isSaved = true }
        await store.finish()
        @Dependency(\.defaultDatabase) var database
        let saved = try await database.read { db in try SavedRead.all.fetchAll(db) }
        #expect(saved.map(\.source) == [.scan])
        #expect(saved.map(\.aimInches) == [19])

        await store.send(.rescanButtonTapped) {
            $0.points = []
            $0.progress = ScanProgress(coverage: 0, prompt: .walkToHole, slope: nil)
            $0.slope = nil
            $0.isSaved = false
            $0.scanID = 1
            $0.step = .mark
        }
    }

    @Test func finishingWithPoorCoverageShowsS4() async {
        var state = ScanFlow.State()
        state.step = .scanning
        state.points = [SIMD3(0, 0, 0), SIMD3(0, 0, -3)]
        state.progress = ScanProgress(coverage: 0.41, prompt: .coverRight, slope: slope)
        let store = TestStore(initialState: state) { ScanFlow() }

        await store.send(.finishScanButtonTapped) { $0.step = .poorScan }
        await store.send(.rescanGapsButtonTapped) { $0.step = .scanning }
        await store.send(.finishScanButtonTapped) { $0.step = .poorScan }
        await store.send(.startOverButtonTapped) {
            $0.points = []
            $0.progress = ScanProgress(coverage: 0, prompt: .walkToHole, slope: nil)
            $0.slope = nil
            $0.scanID = 1
            $0.step = .mark
        }
    }

    @Test func brightSunTurnsOnHighContrast() async {
        let store = TestStore(initialState: ScanFlow.State()) { ScanFlow() }
        await store.send(.lightChanged(isBright: true)) { $0.isBrightSun = true }
        await store.send(.lightChanged(isBright: false)) { $0.isBrightSun = false }
    }

    @Test func exactStimpStepsWithinRange() async {
        let store = TestStore(initialState: GreenSpeedPicker.State(speed: GreenSpeed(stimp: 13))) {
            GreenSpeedPicker()
        }
        await store.send(.exactStimpTapped) { $0.showsExactStimp = true }
        await store.send(.stimpPlusTapped) { $0.speed = GreenSpeed(stimp: 14) }
        await store.send(.stimpPlusTapped)
    }
}
