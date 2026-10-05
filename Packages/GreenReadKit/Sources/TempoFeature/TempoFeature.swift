import ComposableArchitecture
import DesignSystem
import Models
import SwiftUI

/// Metronome sheet. The audio engine arrives in M5; closing the sheet stops playback (Q17).
@Reducer
public struct TempoFeature {
    @ObservableState
    public struct State: Equatable {
        @Shared(.tempoBPM) public var bpm
        public var isPlaying = false

        public init() {}
    }

    public enum Action {
        case minusButtonTapped
        case plusButtonTapped
        case startStopButtonTapped
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .minusButtonTapped:
                state.$bpm.withLock { $0 = max(Tempo.bpmRange.lowerBound, $0 - 1) }
                return .none

            case .plusButtonTapped:
                state.$bpm.withLock { $0 = min(Tempo.bpmRange.upperBound, $0 + 1) }
                return .none

            case .startStopButtonTapped:
                state.isPlaying.toggle()
                return .none
            }
        }
    }
}

public struct TempoView: View {
    let store: StoreOf<TempoFeature>

    public init(store: StoreOf<TempoFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 24) {
            Text("TEMPO").gr(.label).foregroundStyle(GRColor.textSecondary)
            HStack(spacing: 24) {
                CircleIconButton(systemName: "minus", accessibilityLabel: "Slower", kind: .dark) {
                    store.send(.minusButtonTapped)
                }
                Text("\(store.bpm)")
                    .gr(.display)
                    .monospacedDigit()
                    .frame(minWidth: 80)
                CircleIconButton(systemName: "plus", accessibilityLabel: "Faster", kind: .dark) {
                    store.send(.plusButtonTapped)
                }
            }
            Text("BPM").gr(.label).foregroundStyle(GRColor.textSecondary)
            CircleActionButton(
                title: store.isPlaying ? "Stop" : "Start",
                colour: store.isPlaying ? GRColor.ink : GRColor.green
            ) {
                store.send(.startStopButtonTapped)
            }
        }
        .padding(GRMetrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GRColor.chalk)
        .presentationDetents([.medium])
    }
}

#Preview {
    TempoView(store: Store(initialState: TempoFeature.State()) { TempoFeature() })
}
