import ComposableArchitecture
import DesignSystem
import Models
import SwiftUI

/// Onboarding 1b: a single-page tour, shown once on first launch. Permissions are asked
/// later, the first time Scan or Quick Read needs them.
@Reducer
public struct OnboardingFeature {
    @ObservableState
    public struct State: Equatable {
        @Shared(.hasSeenOnboarding) public var hasSeenOnboarding

        public init() {}
    }

    public enum Action {
        case getStartedButtonTapped
    }

    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .getStartedButtonTapped:
                state.$hasSeenOnboarding.withLock { $0 = true }
                return .run { [dismiss] _ in await dismiss() }
            }
        }
    }
}

public struct OnboardingView: View {
    let store: StoreOf<OnboardingFeature>

    public init(store: StoreOf<OnboardingFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Wordmark(size: 22, showsTagline: false)
                .padding(.top, 24)
            Text("Four tools.\nFind the line.")
                .gr(.display)
                .foregroundStyle(GRColor.ink)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: GRMetrics.gap) {
                ToolRow(icon: .circle, title: "Scan", subtitle: "AR putt line", isHero: true)
                ToolRow(icon: .square, title: "Quick Read", subtitle: "Phone flat, instant aim")
                ToolRow(icon: .diamond, title: "Tempo", subtitle: "Metronome & backswing")
                ToolRow(icon: .screen, title: "Drills", subtitle: "Videos from coaches")
            }
            .padding(.top, 24)
            Spacer(minLength: 24)
            PillButton("Get started") {
                store.send(.getStartedButtonTapped)
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .background(GRColor.chalk.ignoresSafeArea())
    }
}

private struct ToolRow: View {
    enum Icon { case circle, square, diamond, screen }

    let icon: Icon
    let title: String
    let subtitle: String
    var isHero = false

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHero ? GRColor.green : GRColor.ink)
                .frame(width: 46, height: 46)
                .overlay { glyph.foregroundStyle(.white) }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).grFont(.archivo(17, weight: 800))
                Text(subtitle)
                    .grFont(.archivo(13, weight: 500))
                    .foregroundStyle(GRColor.textSecondary)
            }
            Spacer()
        }
        .foregroundStyle(GRColor.ink)
        .padding(.horizontal, 14)
        .frame(height: 76)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(GRColor.card))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var glyph: some View {
        switch icon {
        case .circle:
            Circle().strokeBorder(lineWidth: 3).frame(width: 24, height: 24)
        case .square:
            RoundedRectangle(cornerRadius: 3).strokeBorder(lineWidth: 3).frame(width: 22, height: 22)
        case .diamond:
            RoundedRectangle(cornerRadius: 2).strokeBorder(lineWidth: 3).frame(width: 18, height: 18)
                .rotationEffect(.degrees(45))
        case .screen:
            RoundedRectangle(cornerRadius: 4).strokeBorder(lineWidth: 3).frame(width: 24, height: 18)
        }
    }
}

#Preview {
    OnboardingView(store: Store(initialState: OnboardingFeature.State()) { OnboardingFeature() })
}
