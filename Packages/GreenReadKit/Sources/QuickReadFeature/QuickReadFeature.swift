import ComposableArchitecture
import DesignSystem
import SwiftUI

/// Quick Read: the Read | Train switch over two step flows.
@Reducer
public struct QuickReadFeature {
    @ObservableState
    public struct State: Equatable {
        public var mode: Mode.State

        public init(mode: Mode.State = .read(ReadFlow.State())) {
            self.mode = mode
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

        @CasePathable
        public enum Delegate {
            case showStats
        }
    }

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
            }
        }
    }
}

/// Read mode steps. Measure, lay flat and result arrive in M3.
@Reducer
public struct ReadFlow {
    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action {}

    public init() {}

    public var body: some Reducer<State, Action> {
        EmptyReducer()
    }
}

/// Train mode steps. Guess, reveal and summary arrive in M4.
@Reducer
public struct TrainFlow {
    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action {
        case delegate(Delegate)
        case seeStatsButtonTapped

        @CasePathable
        public enum Delegate {
            case showStats
        }
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .delegate:
                return .none

            case .seeStatsButtonTapped:
                return .send(.delegate(.showStats))
            }
        }
    }
}

public struct QuickReadView: View {
    @Bindable var store: StoreOf<QuickReadFeature>

    public init(store: StoreOf<QuickReadFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 20) {
            PillSegmentedControl(
                options: QuickReadFeature.ModeKind.allCases,
                selection: $store.modeKind.sending(\.modeChanged),
                style: .onCamera
            ) { $0.rawValue }
            switch store.scope(state: \.mode, action: \.mode).case {
            case .read:
                Text("Read").gr(.title).foregroundStyle(.white)
            case let .train(trainStore):
                Text("Train").gr(.title).foregroundStyle(.white)
                PillButton("See stats", kind: .secondary) {
                    trainStore.send(.seeStatsButtonTapped)
                }
            }
            Spacer()
        }
    }
}

extension QuickReadFeature.Mode.State: Equatable {}
