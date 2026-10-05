import ComposableArchitecture
import DesignSystem
import Models
import SwiftUI

/// Onboarding 1b: a single-page tour, shown once on first launch. Styled in M2.
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
        VStack(alignment: .leading, spacing: 24) {
            Wordmark(size: 40)
            Text("Four tools. Find the line.").gr(.title)
            Spacer()
            PillButton("Get started") {
                store.send(.getStartedButtonTapped)
            }
        }
        .padding(GRMetrics.screenPadding)
        .background(GRColor.chalk.ignoresSafeArea())
    }
}

#Preview {
    OnboardingView(store: Store(initialState: OnboardingFeature.State()) { OnboardingFeature() })
}
