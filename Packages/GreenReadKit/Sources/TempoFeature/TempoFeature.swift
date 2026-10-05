import Clients
import ComposableArchitecture
import DesignSystem
import Models
import SwiftUI

/// Metronome sheet (prototype / 10a without the tabs). The pendulum and labels follow the
/// beats the audio engine actually plays. Closing the sheet stops it (Q17).
@Reducer
public struct TempoFeature {
    @ObservableState
    public struct State: Equatable {
        @Shared(.tempoBPM) public var bpm
        public var isPlaying = false
        public var lastBeat: TempoBeat?
        @SharedReader(.appSettings) public var settings

        public init() {}
    }

    public enum Action {
        case beat(TempoBeat)
        case minusButtonTapped
        case plusButtonTapped
        case startStopButtonTapped
        case stopped
    }

    enum CancelID { case metronome }

    @Dependency(TempoClient.self) var tempo

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .beat(beat):
                state.lastBeat = beat
                return .none

            case .minusButtonTapped:
                state.$bpm.withLock { $0 = max(Tempo.bpmRange.lowerBound, $0 - 1) }
                return updateTempo(state)

            case .plusButtonTapped:
                state.$bpm.withLock { $0 = min(Tempo.bpmRange.upperBound, $0 + 1) }
                return updateTempo(state)

            case .startStopButtonTapped:
                guard !state.isPlaying else {
                    state.isPlaying = false
                    state.lastBeat = nil
                    return .cancel(id: CancelID.metronome)
                }
                state.isPlaying = true
                let options = TempoOptions(
                    bpm: state.bpm,
                    soundsOn: state.settings.soundsOn,
                    hapticsOn: state.settings.hapticsOn
                )
                return .run { [tempo] send in
                    for await beat in tempo.beats(options) {
                        await send(.beat(beat))
                    }
                    await send(.stopped)
                }
                .cancellable(id: CancelID.metronome, cancelInFlight: true)

            case .stopped:
                state.isPlaying = false
                state.lastBeat = nil
                return .none
            }
        }
    }

    private func updateTempo(_ state: State) -> Effect<Action> {
        guard state.isPlaying else { return .none }
        let bpm = state.bpm
        return .run { [tempo] _ in await tempo.setBPM(bpm) }
    }
}

public struct TempoView: View {
    let store: StoreOf<TempoFeature>

    public init(store: StoreOf<TempoFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 14) {
            Text("Tempo").grFont(.archivo(22, weight: 800))
                .padding(.top, 18)
            Pendulum(beat: store.lastBeat, bpm: store.bpm)
                .frame(width: 240, height: 110)
            HStack(spacing: 26) {
                BPMButton(symbol: "minus", label: "Slower") { store.send(.minusButtonTapped) }
                    .disabled(store.bpm <= Tempo.bpmRange.lowerBound)
                VStack(spacing: 0) {
                    Text("\(store.bpm)")
                        .grFont(.archivo(60, weight: 800, width: 115))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("BPM").gr(.label).foregroundStyle(GRColor.textSecondary)
                }
                .frame(minWidth: 110)
                .accessibilityElement(children: .combine)
                BPMButton(symbol: "plus", label: "Faster") { store.send(.plusButtonTapped) }
                    .disabled(store.bpm >= Tempo.bpmRange.upperBound)
            }
            CircleActionButton(
                title: store.isPlaying ? "Stop" : "Start",
                colour: store.isPlaying ? GRColor.ink : GRColor.green
            ) {
                store.send(.startStopButtonTapped)
            }
            Text(footnote)
                .grFont(.archivo(13, weight: 600))
                .foregroundStyle(GRColor.textSecondary)
        }
        .foregroundStyle(GRColor.ink)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .presentationBackground(GRColor.chalk)
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }

    private var footnote: String {
        let settings = store.settings
        switch (settings.soundsOn, settings.hapticsOn) {
        case (true, true): return "Haptics on · back = tick, through = tock"
        case (true, false): return "Haptics off · back = tick, through = tock"
        case (false, true): return "Sound off · haptics only"
        case (false, false): return "Sound and haptics are off in Settings"
        }
    }
}

/// Rod and green bob swinging ±28° on each beat; BACK / THROUGH light up in turn.
private struct Pendulum: View {
    let beat: TempoBeat?
    let bpm: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Rectangle().fill(GRColor.ink).frame(width: 3, height: 86)
                Circle().fill(GRColor.green).frame(width: 28, height: 28)
            }
            .rotationEffect(.degrees(angle), anchor: .top)
            .animation(reduceMotion ? nil : .easeInOut(duration: min(0.35, 60.0 / Double(bpm) * 0.8)), value: beat)

            HStack {
                label("BACK", lit: beat?.kind == .back)
                Spacer()
                label("THROUGH", lit: beat?.kind == .through)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityElement()
        .accessibilityLabel(beat.map { $0.kind == .back ? "Back" : "Through" } ?? "Stopped")
    }

    private var angle: Double {
        switch beat?.kind {
        case .back: -28
        case .through: 28
        case nil: 0
        }
    }

    private func label(_ text: String, lit: Bool) -> some View {
        Text(text)
            .grFont(.mono(11, weight: 800))
            .foregroundStyle(lit ? GRColor.green : GRColor.textMuted)
    }
}

private struct BPMButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(GRColor.ink)
                .frame(width: 54, height: 54)
                .background(Circle().fill(GRColor.card))
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        TempoView(store: Store(initialState: TempoFeature.State()) { TempoFeature() })
    }
}
