import ComposableArchitecture
import DesignSystem
import SwiftUI

/// Scan steps. The LiDAR gate, marking, scanning and result arrive in M7.
@Reducer
public struct ScanFlow {
    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action {
        case delegate(Delegate)
        case useQuickReadButtonTapped

        @CasePathable
        public enum Delegate {
            case switchToQuickRead
        }
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .delegate:
                return .none

            case .useQuickReadButtonTapped:
                return .send(.delegate(.switchToQuickRead))
            }
        }
    }
}

public struct ScanView: View {
    let store: StoreOf<ScanFlow>

    public init(store: StoreOf<ScanFlow>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 20) {
            Text("Scan").gr(.title).foregroundStyle(.white)
            Spacer()
            PillButton("Use Quick Read instead", kind: .secondary) {
                store.send(.useQuickReadButtonTapped)
            }
        }
    }
}
