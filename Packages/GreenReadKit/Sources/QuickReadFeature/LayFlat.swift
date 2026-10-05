import Clients
import ComposableArchitecture
import DesignSystem
import GreenReadCore
import Models
import SwiftUI

/// Lay flat: orange until the phone is flat and still, then green while it reads.
/// The 60 Hz attitude stream runs through `SlopeReader` inside the effect; only phase
/// changes and ~10 Hz live values reach the store.
@Reducer
public struct LayFlat {
    @ObservableState
    public struct State: Equatable {
        public var phase: SlopeReader.Phase = .notFlat(live: SlopeReading(uphillPercent: 0, sidePercent: 0))
        /// Train mode hides the live numbers ("no peeking").
        public var hidesNumbers: Bool
        @SharedReader(.appSettings) public var settings

        public init(hidesNumbers: Bool = false) {
            self.hidesNumbers = hidesNumbers
        }

        var isGreen: Bool {
            switch phase {
            case .notFlat, .flat: false
            case .reading, .done: true
            }
        }
    }

    public enum Action {
        case delegate(Delegate)
        case phaseChanged(SlopeReader.Phase)
        case task

        @CasePathable
        public enum Delegate {
            case finished(SlopeReading)
        }
    }

    /// Live values refresh at most this often.
    static let liveInterval: TimeInterval = 0.1

    @Dependency(MotionClient.self) var motion

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none

            case let .phaseChanged(phase):
                state.phase = phase
                if case let .done(reading) = phase {
                    return .send(.delegate(.finished(reading)))
                }
                return .none

            case .task:
                return .run { [motion] send in
                    var reader = SlopeReader()
                    var lastSent: SlopeReader.Phase?
                    var lastSentAt = -Double.infinity
                    for await sample in motion.attitudeUpdates() {
                        let phase = reader.ingest(sample)
                        let isNewPhase = lastSent.map { !$0.isSameStage(as: phase) } ?? true
                        if isNewPhase || sample.time - lastSentAt >= Self.liveInterval {
                            lastSent = phase
                            lastSentAt = sample.time
                            await send(.phaseChanged(phase))
                        }
                        if case .done = phase { return }
                    }
                }
            }
        }
    }
}

extension SlopeReader.Phase {
    func isSameStage(as other: Self) -> Bool {
        switch (self, other) {
        case (.notFlat, .notFlat), (.flat, .flat), (.reading, .reading), (.done, .done): true
        default: false
        }
    }

    var live: SlopeReading? {
        switch self {
        case let .notFlat(live), let .flat(live), let .reading(_, live): live
        case let .done(reading): reading
        }
    }
}

struct LayFlatView: View {
    let store: StoreOf<LayFlat>

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 120)
            Triangle()
                .fill(.white)
                .frame(width: 124, height: 88)
                .accessibilityHidden(true)
            Text("TOP EDGE → HOLE")
                .grFont(.mono(15, weight: 800))
                .tracking(1.5)
                .padding(.top, 14)
            VStack(spacing: 12) {
                statusRow("Flat", value: isFlat ? "✓" : "—")
                statusRow("Aimed", value: store.isGreen ? "✓" : "↻ turn")
            }
            .frame(width: 250)
            .padding(.top, 36)
            if store.hidesNumbers {
                if isFlat {
                    Text("Your guess is locked · no peeking")
                        .grFont(.archivo(14, weight: 700))
                        .padding(.top, 16)
                }
            } else if let live = store.phase.live {
                // Always laid out, so the screen doesn't jump when the chips fade in.
                HStack(spacing: 10) {
                    liveChip("UPHILL", Format.slope(percent: live.uphillPercent))
                    liveChip(sideLabel(live), Format.slope(percent: live.sidePercent))
                }
                .padding(.top, 16)
                .opacity(store.isGreen ? 1 : 0)
            }
            Spacer()
            Text(title)
                .grFont(.archivo(30, weight: 800, width: 115))
                .padding(.bottom, 44)
                .contentTransition(.opacity)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background((store.isGreen ? GRColor.green : GRColor.clay).ignoresSafeArea())
        .animation(GRMotion.stateColour, value: store.isGreen)
        .sensoryFeedback(.impact(weight: .light), trigger: store.isGreen) { _, isGreen in
            isGreen && store.settings.hapticsOn
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .task { await store.send(.task).finish() }
    }

    private var isFlat: Bool {
        if case .notFlat = store.phase { return false }
        return true
    }

    private var title: String {
        switch store.phase {
        case .notFlat: "Lay the phone flat"
        case .flat: "Turn top edge to hole"
        case .reading: "Reading…"
        case .done: "Got it"
        }
    }

    private func sideLabel(_ live: SlopeReading) -> String {
        live.breakDirection == .straight ? "SIDE" : "SIDE · \(live.breakDirection.label)"
    }

    private func statusRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
        }
        .grFont(.archivo(24, weight: 800))
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.18)))
    }

    private func liveChip(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            Text(label).gr(.labelSmall).foregroundStyle(GRColor.textSecondary)
            Text(value).grFont(.archivo(22, weight: 800)).monospacedDigit()
        }
        .foregroundStyle(GRColor.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
    }
}
