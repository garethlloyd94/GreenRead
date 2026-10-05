import Clients
import ComposableArchitecture
import DesignSystem
import GreenReadCore
import Models
import SwiftUI

/// Step 1 · Distance: tap ball then hole on the camera, walk it off, or enter it manually.
@Reducer
public struct Measure {
    @ObservableState
    public struct State: Equatable {
        public var method: Method = .camera
        /// Ball, then hole, in AR world coordinates (metres).
        public var points: [SIMD3<Float>] = []
        public var manualFeet: Double = 15
        public var walkSteps = 0
        public var isCameraAvailable = true
        public var isPedometerAvailable = true
        @SharedReader(.appSettings) public var settings

        public init() {}

        /// The measured distance, once there is one.
        public var feet: Double? {
            switch method {
            case .camera:
                guard points.count == 2 else { return nil }
                let delta = points[1] - points[0]
                let metres = Double((delta.x * delta.x + delta.z * delta.z).squareRoot())
                return metres / DistanceUnit.metresPerFoot
            case .manual:
                return manualFeet
            case .walk:
                return walkSteps > 0 ? Double(walkSteps) * settings.paceLengthFeet : nil
            }
        }
    }

    public enum Method: Equatable, Sendable {
        case camera, manual, walk
    }

    public static let manualRange: ClosedRange<Double> = 3...60

    public enum Action {
        case arPointPlaced(SIMD3<Float>)
        case cameraPermissionResponse(Bool)
        case delegate(Delegate)
        case distanceMinusTapped
        case distancePlusTapped
        case enterManuallyTapped
        case nextButtonTapped
        case task
        case undoTapped
        case useCameraTapped
        case walkFailed
        case walkItOffTapped
        case walkStepsUpdated(Int)

        @CasePathable
        public enum Delegate {
            case measured(feet: Double)
        }
    }

    enum CancelID { case walk }

    @Dependency(ARMeasureClient.self) var arMeasure
    @Dependency(PedometerClient.self) var pedometer
    @Dependency(PermissionsClient.self) var permissions

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .arPointPlaced(point):
                guard state.method == .camera, state.points.count < 2 else { return .none }
                state.points.append(point)
                return .none

            case let .cameraPermissionResponse(granted):
                if !granted {
                    state.isCameraAvailable = false
                    state.method = .manual
                }
                return .none

            case .delegate:
                return .none

            case .distanceMinusTapped:
                state.manualFeet = max(Self.manualRange.lowerBound, state.manualFeet - 1)
                return .none

            case .distancePlusTapped:
                state.manualFeet = min(Self.manualRange.upperBound, state.manualFeet + 1)
                return .none

            case .enterManuallyTapped:
                state.method = .manual
                return .cancel(id: CancelID.walk)

            case .nextButtonTapped:
                guard let feet = state.feet else { return .none }
                return .merge(
                    .cancel(id: CancelID.walk),
                    .send(.delegate(.measured(feet: feet)))
                )

            case .task:
                state.isPedometerAvailable = pedometer.isAvailable()
                guard arMeasure.isSupported() else {
                    state.isCameraAvailable = false
                    state.method = .manual
                    return .none
                }
                switch permissions.cameraStatus() {
                case .authorized:
                    return .none
                case .denied:
                    state.isCameraAvailable = false
                    state.method = .manual
                    return .none
                case .notDetermined:
                    return .run { [permissions] send in
                        await send(.cameraPermissionResponse(permissions.requestCamera()))
                    }
                }

            case .undoTapped:
                _ = state.points.popLast()
                return .none

            case .useCameraTapped:
                state.method = .camera
                return .cancel(id: CancelID.walk)

            case .walkFailed:
                state.method = .manual
                state.isPedometerAvailable = false
                return .none

            case .walkItOffTapped:
                state.method = .walk
                state.walkSteps = 0
                return .run { [pedometer] send in
                    do {
                        for try await steps in pedometer.steps() {
                            await send(.walkStepsUpdated(steps))
                        }
                    } catch {
                        await send(.walkFailed)
                    }
                }
                .cancellable(id: CancelID.walk, cancelInFlight: true)

            case let .walkStepsUpdated(steps):
                state.walkSteps = steps
                return .none
            }
        }
    }
}

struct MeasureView: View {
    let store: StoreOf<Measure>
    var title = "STEP 1 · DISTANCE"
    var nextLabel = "Next · lay phone flat"

    var body: some View {
        ZStack(alignment: .bottom) {
            camera
                .ignoresSafeArea()
            card
                .padding(.horizontal, 14)
                .padding(.bottom, 18)
        }
        .task { await store.send(.task).finish() }
    }

    @ViewBuilder private var camera: some View {
        if store.isCameraAvailable && store.method == .camera {
            ARMeasureView(points: store.points) { store.send(.arPointPlaced($0)) }
        } else {
            StripedPlaceholder(dark: GRColor.turfDark, light: GRColor.turfLight, stripe: 12)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).gr(.labelSmall).foregroundStyle(GRColor.textSecondary)
                    if let feet = store.feet {
                        Text(store.settings.distance(feet: feet))
                            .font(GRFont.archivo(36, weight: 800))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    } else {
                        Text(prompt)
                            .font(GRFont.archivo(22, weight: 800))
                            .padding(.top, 4)
                    }
                }
                Spacer()
                switch store.method {
                case .manual:
                    HStack(spacing: 8) {
                        RoundStepButton(symbol: "minus", label: "Shorter") { store.send(.distanceMinusTapped) }
                        RoundStepButton(symbol: "plus", label: "Longer") { store.send(.distancePlusTapped) }
                    }
                case .camera:
                    if !store.points.isEmpty {
                        RoundStepButton(symbol: "arrow.uturn.backward", label: "Undo") { store.send(.undoTapped) }
                    }
                case .walk:
                    EmptyView()
                }
            }
            .foregroundStyle(GRColor.ink)

            HStack(spacing: 16) {
                if store.method == .camera {
                    TextLinkButton(title: "Enter manually") { store.send(.enterManuallyTapped) }
                } else if store.isCameraAvailable {
                    TextLinkButton(title: "Use camera") { store.send(.useCameraTapped) }
                } else if store.method == .walk {
                    TextLinkButton(title: "Enter manually") { store.send(.enterManuallyTapped) }
                }
                if store.isPedometerAvailable && store.method != .walk {
                    TextLinkButton(title: "Walk it off") { store.send(.walkItOffTapped) }
                }
            }

            if store.feet != nil {
                PillButton(nextLabel, kind: .neutral) { store.send(.nextButtonTapped) }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(GRColor.card))
        .animation(GRMotion.fade, value: store.feet == nil)
    }

    private var prompt: String {
        switch store.method {
        case .camera: store.points.isEmpty ? "Tap the ball" : "Now tap the hole"
        case .manual: "Set the distance"
        case .walk: "Walk ball → hole · \(store.walkSteps) steps"
        }
    }
}

/// 48pt round grey button used in the measure card.
struct RoundStepButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(GRColor.ink)
                .frame(width: GRMetrics.minTapTarget, height: GRMetrics.minTapTarget)
                .background(Circle().fill(GRColor.fill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
