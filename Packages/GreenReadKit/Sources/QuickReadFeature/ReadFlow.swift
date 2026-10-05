import ComposableArchitecture
import GreenReadCore
import Models
import SwiftUI

/// Read mode: Measure → Lay flat → Result. Steps replace each other in place.
@Reducer
public struct ReadFlow {
    @ObservableState
    public struct State: Equatable {
        public var step: Step.State = .measure(Measure.State())
        public var feet: Double?
        @SharedReader(.appSettings) public var settings

        public init() {}
    }

    @Reducer
    public enum Step {
        case layFlat(LayFlat)
        case measure(Measure)
        case result(ReadResult)
    }

    public enum Action {
        case step(Step.Action)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Scope(state: \.step, action: \.step) {
            Step.body
        }
        Reduce { state, action in
            switch action {
            case let .step(.measure(.delegate(.measured(feet)))):
                state.feet = feet
                state.step = .layFlat(LayFlat.State())
                return .none

            case let .step(.layFlat(.delegate(.finished(reading)))):
                guard let feet = state.feet else { return .none }
                state.step = .result(
                    ReadResult.State(feet: feet, reading: reading, speed: state.settings.defaultSpeed)
                )
                return .none

            case .step(.result(.delegate(.newRead))):
                state.feet = nil
                state.step = .measure(Measure.State())
                return .none

            case .step:
                return .none
            }
        }
    }
}

extension ReadFlow.Step.State: Equatable {}

struct ReadFlowView: View {
    let store: StoreOf<ReadFlow>

    var body: some View {
        switch store.scope(state: \.step, action: \.step).case {
        case let .measure(store):
            MeasureView(store: store)
        case let .layFlat(store):
            LayFlatView(store: store)
        case let .result(store):
            ReadResultView(store: store)
        }
    }
}
