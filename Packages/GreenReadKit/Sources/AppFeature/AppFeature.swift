import ComposableArchitecture
import DesignSystem
import DrillsFeature
import HomeFeature
import Models
import GreenReadCore
import OnboardingFeature
import QuickReadFeature
import SettingsFeature
import StatsFeature
import SwiftUI
import TempoFeature
import ToolFeature

/// Root of the app: Home always, a stack path for pushed screens, and one destination for
/// everything presented over Home.
@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        @Presents public var destination: AppDestination.State?
        public var home = HomeFeature.State()
        public var path = StackState<AppPath.State>()

        public init() {
            @Shared(.hasSeenOnboarding) var hasSeenOnboarding
            if !hasSeenOnboarding {
                destination = .onboarding(OnboardingFeature.State())
            }
        }
    }

    public enum Action {
        case destination(PresentationAction<AppDestination.Action>)
        case home(HomeFeature.Action)
        case path(StackActionOf<AppPath>)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Reduce { state, action in
            switch action {
            case .destination(.presented(.tool(.delegate(.showStats)))):
                state.destination = nil
                state.path.append(.stats(StatsFeature.State()))
                return .none

            case .destination:
                return .none

            case let .home(.delegate(delegate)):
                switch delegate {
                case let .openPlayer(videoID):
                    state.path.append(.player(PlayerFeature.State(videoID: videoID)))
                case .openQuickRead:
                    state.destination = .tool(.quickRead)
                case .openScan:
                    state.destination = .tool(.scan)
                case .openSettings:
                    state.destination = .settings(SettingsFeature.State())
                case .openStats:
                    state.path.append(.stats(StatsFeature.State()))
                case .openTempo:
                    state.destination = .tempo(TempoFeature.State())
                }
                return .none

            case .home:
                return .none

            case .path:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .forEach(\.path, action: \.path)
    }
}

/// Screens pushed full-screen with a ‹ back button.
@Reducer
public enum AppPath {
    case player(PlayerFeature)
    case stats(StatsFeature)
}

/// Everything presented over Home.
@Reducer
public enum AppDestination {
    case onboarding(OnboardingFeature)
    case settings(SettingsFeature)
    case tempo(TempoFeature)
    case tool(ToolFeature)
}

public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            HomeView(store: store.scope(state: \.home, action: \.home))
        } destination: { pathStore in
            switch pathStore.case {
            case let .player(playerStore):
                PlayerView(store: playerStore)
            case let .stats(statsStore):
                StatsView(store: statsStore)
            }
        }
        .fullScreenCover(
            item: $store.scope(state: \.destination?.onboarding, action: \.destination.onboarding)
        ) { onboardingStore in
            OnboardingView(store: onboardingStore)
        }
        .fullScreenCover(item: $store.scope(state: \.destination?.tool, action: \.destination.tool)) { toolStore in
            ToolView(store: toolStore)
        }
        .sheet(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { settingsStore in
            SettingsView(store: settingsStore)
        }
        .sheet(item: $store.scope(state: \.destination?.tempo, action: \.destination.tempo)) { tempoStore in
            TempoView(store: tempoStore)
        }
        .tint(GRColor.green)
    }
}

#Preview {
    let _ = prepareDependencies { try! $0.bootstrapDatabase() }
    AppView(store: Store(initialState: AppFeature.State()) { AppFeature() })
}

extension AppPath.State: Equatable {}
extension AppDestination.State: Equatable {}

#if DEBUG
extension AppFeature.State {
    /// Opens a screen by name at launch; see `GreenReadApp.initialState()`.
    public mutating func openForDebugging(_ screen: String) {
        switch screen {
        case "quickRead": destination = .tool(.quickRead)
        case "quickRead.layFlat", "quickRead.result":
            var read = ReadFlow.State()
            read.feet = 15
            read.step = screen == "quickRead.layFlat"
                ? .layFlat(LayFlat.State())
                : .result(ReadResult.State(
                    feet: 15,
                    reading: SlopeReading(uphillPercent: 1.2, sidePercent: 2.1),
                    speed: .medium
                ))
            var quickRead = QuickReadFeature.State(mode: .read(read))
            quickRead.hasCheckedPermission = true
            destination = .tool(ToolFeature.State(tool: .quickRead(quickRead)))
        case "scan": destination = .tool(.scan)
        case "settings": destination = .settings(SettingsFeature.State())
        case "stats": path.append(.stats(StatsFeature.State()))
        case "tempo": destination = .tempo(TempoFeature.State())
        default: break
        }
    }
}
#endif
