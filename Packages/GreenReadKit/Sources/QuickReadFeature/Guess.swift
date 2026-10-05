import ComposableArchitecture
import DesignSystem
import GreenReadCore
import Models
import SwiftUI

/// Train · make your read before the phone does (design 6a).
@Reducer
public struct Guess {
    @ObservableState
    public struct State: Equatable {
        public var feet: Double
        public var puttIndex: Int
        public var slopePercent: Int?
        public var breakDirection: BreakDirection?
        public var hill: Hill?
        public var aimInches = 12
        @SharedReader(.appSettings) public var settings

        public init(feet: Double, puttIndex: Int) {
            self.feet = feet
            self.puttIndex = puttIndex
        }

        public var guess: TrainGuess? {
            guard let slopePercent, let breakDirection, let hill else { return nil }
            return TrainGuess(slopePercent: slopePercent, breakDirection: breakDirection, hill: hill, aimInches: aimInches)
        }
    }

    public enum Action: BindableAction {
        case aimMinusTapped
        case aimPlusTapped
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case lockInButtonTapped

        @CasePathable
        public enum Delegate {
            case locked(TrainGuess)
        }
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .aimMinusTapped:
                state.aimInches = max(0, state.aimInches - 1)
                return .none

            case .aimPlusTapped:
                state.aimInches += 1
                return .none

            case .binding, .delegate:
                return .none

            case .lockInButtonTapped:
                guard let guess = state.guess else { return .none }
                return .send(.delegate(.locked(guess)))
            }
        }
    }
}

struct GuessView: View {
    @Bindable var store: StoreOf<Guess>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your read · \(store.settings.distance(feet: store.feet))")
                    .gr(.title)
                Spacer()
                PuttDots(current: store.puttIndex, onDark: false)
            }
            ChipGroup(label: "SLOPE", options: Array(TrainScoring.slopeChoices), selection: $store.slopePercent) {
                "\($0)%"
            }
            ChipGroup(
                label: "BREAK",
                options: [BreakDirection.leftToRight, .rightToLeft, .straight],
                selection: $store.breakDirection
            ) { $0.label }
            ChipGroup(label: "HILL", options: [Hill.up, .flat, .down], selection: $store.hill) { $0.label }
            VStack(alignment: .leading, spacing: 7) {
                Text(aimLabel).gr(.label).foregroundStyle(GRColor.textSecondary)
                HStack {
                    aimButton("minus", label: "Less aim") { store.send(.aimMinusTapped) }
                    Spacer()
                    Text(store.settings.aim(inches: store.aimInches).amount)
                        .grFont(.archivo(22, weight: 800))
                        .monospacedDigit()
                    Spacer()
                    aimButton("plus", label: "More aim") { store.send(.aimPlusTapped) }
                }
                .padding(.horizontal, 7)
                .frame(height: 58)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(GRColor.card))
                .accessibilityElement(children: .contain)
            }
            Spacer()
            if store.guess != nil {
                PillButton("Lock in & lay phone") { store.send(.lockInButtonTapped) }
            } else {
                Text("Pick slope, break & hill")
                    .gr(.button)
                    .foregroundStyle(GRColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Capsule().fill(GRColor.border))
            }
        }
        .foregroundStyle(GRColor.ink)
        .padding(.horizontal, GRMetrics.screenPadding)
        .padding(.top, 116)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GRColor.chalk.ignoresSafeArea())
    }

    private var aimLabel: String {
        switch store.settings.aimUnit {
        case .inches: "AIM (INCHES OUTSIDE CUP)"
        case .cups: "AIM (INCHES · SHOWN IN CUPS)"
        case .balls: "AIM (INCHES · SHOWN IN BALLS)"
        }
    }

    private func aimButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(GRColor.ink)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(GRColor.fill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Five dots for the round: done = green, current = ink (lime on camera), to come = grey.
struct PuttDots: View {
    let current: Int
    var onDark = true

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<TrainScoring.puttsPerRound, id: \.self) { index in
                Circle()
                    .fill(colour(index))
                    .frame(width: 10, height: 10)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Putt \(current + 1) of \(TrainScoring.puttsPerRound)")
    }

    private func colour(_ index: Int) -> Color {
        if index < current { return GRColor.green }
        if index == current { return onDark ? GRColor.lime : GRColor.ink }
        return onDark ? .white.opacity(0.35) : GRColor.textOnDarkMuted
    }
}
