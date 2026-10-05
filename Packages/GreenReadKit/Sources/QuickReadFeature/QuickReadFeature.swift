import Clients
import ComposableArchitecture
import DesignSystem
import SwiftUI

/// Quick Read: the S7 motion primer on first use, then the Read | Train switch over two step flows.
@Reducer
public struct QuickReadFeature {
    @ObservableState
    public struct State: Equatable {
        public var hasCheckedPermission = false
        public var mode: Mode.State
        @Presents public var primer: MotionPrimer.State?

        public init(mode: Mode.State = .read(ReadFlow.State())) {
            self.mode = mode
        }

        /// True over the camera and the lay-flat colours, false over chalk screens.
        public var isOverDarkBackground: Bool {
            guard hasCheckedPermission, primer == nil else { return false }
            switch mode {
            case let .read(read):
                switch read.step {
                case .measure, .layFlat: return true
                case .result: return false
                }
            case let .train(train):
                switch train.step {
                case .measure, .layFlat: return true
                case .guess, .reveal, .summary: return false
                }
            }
        }

        public var modeKind: ModeKind {
            switch mode {
            case .read: .read
            case .train: .train
            }
        }
    }

    @Reducer
    public enum Mode {
        case read(ReadFlow)
        case train(TrainFlow)
    }

    public enum ModeKind: String, CaseIterable, Sendable {
        case read = "Read"
        case train = "Train"
    }

    public enum Action {
        case delegate(Delegate)
        case mode(Mode.Action)
        case modeChanged(ModeKind)
        case primer(PresentationAction<MotionPrimer.Action>)
        case task

        @CasePathable
        public enum Delegate {
            case close
            case showStats
        }
    }

    @Dependency(PermissionsClient.self) var permissions

    public init() {}

    public var body: some Reducer<State, Action> {
        Scope(state: \.mode, action: \.mode) {
            Mode.body
        }
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none

            case .mode(.train(.delegate(.showStats))):
                return .send(.delegate(.showStats))

            case .mode:
                return .none

            case let .modeChanged(kind):
                guard kind != state.modeKind else { return .none }
                switch kind {
                case .read: state.mode = .read(ReadFlow.State())
                case .train: state.mode = .train(TrainFlow.State())
                }
                return .none

            case .primer(.presented(.delegate(.granted))):
                state.primer = nil
                return .none

            case .primer(.presented(.delegate(.notNow))):
                return .send(.delegate(.close))

            case .primer:
                return .none

            case .task:
                guard !state.hasCheckedPermission else { return .none }
                state.hasCheckedPermission = true
                switch permissions.motionStatus() {
                case .authorized: break
                case .notDetermined: state.primer = MotionPrimer.State()
                case .denied: state.primer = MotionPrimer.State(isDenied: true)
                }
                return .none
            }
        }
        .ifLet(\.$primer, action: \.primer) {
            MotionPrimer()
        }
    }
}

extension QuickReadFeature.Mode.State: Equatable {}

public struct QuickReadView: View {
    @Bindable var store: StoreOf<QuickReadFeature>

    public init(store: StoreOf<QuickReadFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            if !store.hasCheckedPermission {
                GRColor.ink.ignoresSafeArea()
            } else if let primerStore = store.scope(state: \.primer, action: \.primer.presented) {
                MotionPrimerView(store: primerStore)
            } else {
                ZStack(alignment: .top) {
                    switch store.scope(state: \.mode, action: \.mode).case {
                    case let .read(readStore):
                        ReadFlowView(store: readStore)
                    case let .train(trainStore):
                        TrainFlowView(store: trainStore)
                    }
                    PillSegmentedControl(
                        options: QuickReadFeature.ModeKind.allCases,
                        selection: $store.modeKind.sending(\.modeChanged),
                        style: store.isOverDarkBackground ? .onCamera : .light
                    ) { $0.rawValue }
                    .frame(width: 220)
                    .padding(.top, 60)
                }
            }
        }
        .task { await store.send(.task).finish() }
    }
}
