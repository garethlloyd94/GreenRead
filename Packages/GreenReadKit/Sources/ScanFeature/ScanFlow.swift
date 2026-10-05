import Clients
import ComposableArchitecture
import DesignSystem
import GreenReadCore
import Models
import SQLiteData
import SwiftUI
import UIKit

/// Scan: LiDAR gate (S3), camera primer (S6), Mark ball & hole (S1), Scanning (2a) with
/// poor-scan (S4) and bright-sun (S5) states, Green speed (S2), then the Result (3a).
///
/// The steps share one AR session, so they are plain state on this feature rather than
/// separate child features; the AR view reports taps and throttled scan progress.
@Reducer
public struct ScanFlow {
    @ObservableState
    public struct State: Equatable {
        public var step: Step = .checking
        /// Ball, then hole, in AR world coordinates (metres).
        public var points: [SIMD3<Float>] = []
        public var progress = ScanProgress(coverage: 0, prompt: .walkToHole, slope: nil)
        public var isBrightSun = false
        /// Bumped by Start over / Rescan so the AR view drops its scan data.
        public var scanID = 0
        public var slope: SlopeReading?
        public var speed: GreenSpeed?
        public var isSaved = false
        @Presents public var greenSpeed: GreenSpeedPicker.State?
        @SharedReader(.appSettings) public var settings

        public init() {}

        public var ball: SIMD3<Float>? { points.first }
        public var hole: SIMD3<Float>? { points.count > 1 ? points[1] : nil }

        /// Horizontal ball→hole distance.
        public var feet: Double? {
            guard let ball, let hole else { return nil }
            let delta = hole - ball
            return Double((delta.x * delta.x + delta.z * delta.z).squareRoot()) / DistanceUnit.metresPerFoot
        }

        public var result: AimResult? {
            guard let feet, let slope, let speed else { return nil }
            return TourRead.read(feet: feet, slope: slope, speed: speed)
        }
    }

    public enum Step: Equatable, Sendable {
        case checking
        case noLiDAR
        case cameraPrimer(isDenied: Bool)
        case mark
        case scanning
        case poorScan
        case result
    }

    public enum Action {
        case allowCameraButtonTapped
        case appBecameActive
        case arPointPlaced(SIMD3<Float>)
        case cameraPermissionResponse(Bool)
        case delegate(Delegate)
        case finishScanButtonTapped
        case greenSpeed(PresentationAction<GreenSpeedPicker.Action>)
        case lightChanged(isBright: Bool)
        case openSettingsButtonTapped
        case rescanButtonTapped
        case rescanGapsButtonTapped
        case saveButtonTapped
        case scanProgressed(ScanProgress)
        case startOverButtonTapped
        case startScanButtonTapped
        case task
        case undoButtonTapped
        case useQuickReadButtonTapped

        @CasePathable
        public enum Delegate {
            case switchToQuickRead
        }
    }

    @Dependency(ARMeasureClient.self) var ar
    @Dependency(\.date.now) var now
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.openURL) var openURL
    @Dependency(PermissionsClient.self) var permissions
    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .allowCameraButtonTapped:
                return .run { [permissions] send in
                    await send(.cameraPermissionResponse(permissions.requestCamera()))
                }

            case .appBecameActive:
                guard state.step == .cameraPrimer(isDenied: true), permissions.cameraStatus() == .authorized
                else { return .none }
                state.step = .mark
                return .none

            case let .arPointPlaced(point):
                guard state.step == .mark, state.points.count < 2 else { return .none }
                state.points.append(point)
                return .none

            case let .cameraPermissionResponse(granted):
                state.step = granted ? .mark : .cameraPrimer(isDenied: true)
                return .none

            case .delegate:
                return .none

            case .finishScanButtonTapped:
                finish(&state)
                return .none

            case let .greenSpeed(.presented(.delegate(.showLine(speed)))):
                state.speed = speed
                state.greenSpeed = nil
                state.step = .result
                return .none

            case .greenSpeed:
                return .none

            case let .lightChanged(isBright):
                state.isBrightSun = isBright
                return .none

            case .openSettingsButtonTapped:
                return .run { [openURL] _ in
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    await openURL(url)
                }

            case .rescanButtonTapped, .startOverButtonTapped:
                startOver(&state)
                return .none

            case .rescanGapsButtonTapped:
                state.step = .scanning
                return .none

            case .saveButtonTapped:
                guard !state.isSaved, let result = state.result, let speed = state.speed else { return .none }
                state.isSaved = true
                let read = SavedRead(
                    id: uuid(),
                    savedAt: now,
                    source: .scan,
                    distanceFeet: result.breakdown.feet,
                    uphillPercent: result.reading.uphillPercent,
                    sidePercent: result.reading.sidePercent,
                    stimp: speed.stimp,
                    aimInches: result.aimInches
                )
                return .run { [database] _ in
                    try await database.write { db in
                        try SavedRead.insert { read }.execute(db)
                    }
                }

            case let .scanProgressed(progress):
                guard state.step == .scanning else { return .none }
                state.progress = progress
                if progress.coverage >= CorridorScanner.completeCoverage, progress.slope != nil {
                    finish(&state)
                }
                return .none

            case .startScanButtonTapped:
                guard state.points.count == 2 else { return .none }
                state.step = .scanning
                return .none

            case .task:
                guard state.step == .checking else { return .none }
                guard ar.supportsLiDAR() else {
                    state.step = .noLiDAR
                    return .none
                }
                switch permissions.cameraStatus() {
                case .authorized: state.step = .mark
                case .notDetermined: state.step = .cameraPrimer(isDenied: false)
                case .denied: state.step = .cameraPrimer(isDenied: true)
                }
                return .none

            case .undoButtonTapped:
                _ = state.points.popLast()
                return .none

            case .useQuickReadButtonTapped:
                return .send(.delegate(.switchToQuickRead))
            }
        }
        .ifLet(\.$greenSpeed, action: \.greenSpeed) {
            GreenSpeedPicker()
        }
    }

    private func finish(_ state: inout State) {
        guard state.step == .scanning else { return }
        guard state.progress.coverage >= CorridorScanner.goodCoverage, let slope = state.progress.slope else {
            state.step = .poorScan
            return
        }
        state.slope = slope
        state.greenSpeed = GreenSpeedPicker.State(speed: state.speed ?? state.settings.defaultSpeed)
    }

    private func startOver(_ state: inout State) {
        state.points.removeAll()
        state.progress = ScanProgress(coverage: 0, prompt: .walkToHole, slope: nil)
        state.slope = nil
        state.isSaved = false
        state.scanID += 1
        state.step = .mark
    }
}

// MARK: - Green speed (S2)

@Reducer
public struct GreenSpeedPicker {
    @ObservableState
    public struct State: Equatable {
        public var speed: GreenSpeed
        public var showsExactStimp = false

        public init(speed: GreenSpeed) {
            self.speed = speed
        }
    }

    public enum Action {
        case delegate(Delegate)
        case exactStimpTapped
        case presetTapped(GreenSpeed)
        case showLineButtonTapped
        case stimpMinusTapped
        case stimpPlusTapped

        @CasePathable
        public enum Delegate {
            case showLine(GreenSpeed)
        }
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none
            case .exactStimpTapped:
                state.showsExactStimp.toggle()
                return .none
            case let .presetTapped(speed):
                state.speed = speed
                return .none
            case .showLineButtonTapped:
                return .send(.delegate(.showLine(state.speed)))
            case .stimpMinusTapped:
                state.speed = GreenSpeed(stimp: state.speed.stimp - 1)
                return .none
            case .stimpPlusTapped:
                state.speed = GreenSpeed(stimp: state.speed.stimp + 1)
                return .none
            }
        }
    }
}
