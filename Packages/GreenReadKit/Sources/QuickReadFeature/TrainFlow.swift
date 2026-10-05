import ComposableArchitecture
import DesignSystem
import SwiftUI

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

struct TrainFlowView: View {
    let store: StoreOf<TrainFlow>

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Train arrives in M4").gr(.title).foregroundStyle(.white)
            PillButton("See stats", kind: .secondary) {
                store.send(.seeStatsButtonTapped)
            }
            Spacer()
        }
        .padding(GRMetrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GRColor.turfDark.ignoresSafeArea())
    }
}
