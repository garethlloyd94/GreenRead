import ComposableArchitecture
import DesignSystem
import DrillsFeature
import HomeFeature
import Models
import GreenReadCore
import OnboardingFeature
import QuickReadFeature
import ScanFeature
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

        public init(destination: AppDestination.State? = nil) {
            self.destination = destination
        }

        /// The state the app starts in: onboarding over Home until the golfer has seen it.
        /// Read here, at launch, rather than in `init`, so building state has no hidden inputs.
        public static func launch() -> Self {
            @SharedReader(.hasSeenOnboarding) var hasSeenOnboarding
            return Self(destination: hasSeenOnboarding ? nil : .onboarding(OnboardingFeature.State()))
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
                case let .openPlayer(drill, upNext):
                    state.path.append(.player(PlayerFeature.State(drill: drill, upNext: upNext)))
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

            case let .path(.element(id, .stats(.delegate(.playTrainRound)))):
                state.path.pop(from: id)
                state.destination = .tool(
                    ToolFeature.State(tool: .quickRead(QuickReadFeature.State(mode: .train(TrainFlow.State()))))
                )
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
    AppView(store: Store(initialState: AppFeature.State.launch()) { AppFeature() })
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
        case let name where name.hasPrefix("scan."):
            var scan = ScanFlow.State()
            let slope = SlopeReading(uphillPercent: 1.2, sidePercent: -1.6)
            scan.points = [SIMD3(0, 0, 0), SIMD3(0, 0.04, -3.05)]
            switch name {
            case "scan.noLiDAR": scan.step = .noLiDAR; scan.points = []
            case "scan.camera": scan.step = .cameraPrimer(isDenied: false); scan.points = []
            case "scan.mark": scan.step = .mark; scan.points = [SIMD3(0, 0, 0)]
            case "scan.scanning", "scan.sun":
                scan.step = .scanning
                scan.progress = ScanProgress(coverage: 0.6, prompt: .coverLeft, slope: slope)
                scan.isBrightSun = name == "scan.sun"
            case "scan.poor":
                scan.step = .poorScan
                scan.progress = ScanProgress(coverage: 0.41, prompt: .coverLeft, slope: slope)
            case "scan.speed":
                scan.step = .scanning
                scan.progress = ScanProgress(coverage: 0.96, prompt: .walkToHole, slope: slope)
                scan.slope = slope
                scan.greenSpeed = GreenSpeedPicker.State(speed: .medium)
            default:
                scan.step = .result
                scan.slope = slope
                scan.speed = .medium
            }
            destination = .tool(ToolFeature.State(tool: .scan(scan)))
        case "settings": destination = .settings(SettingsFeature.State())
        case "stats": path.append(.stats(StatsFeature.State()))
        case "drills": home.segment = .drills
        case "player":
            @Dependency(DrillCatalogClient.self) var catalog
            let drills = (try? catalog.load()) ?? []
            if let first = drills.first {
                path.append(.player(PlayerFeature.State(drill: first, upNext: Array(drills.dropFirst()))))
            }
        case "quickRead.train", "train.guess", "train.reveal", "train.summary":
            var train = TrainFlow.State()
            let sample = TrainFlow.debugSamples
            switch screen {
            case "train.guess":
                train.step = .guess(Guess.State(feet: 15, puttIndex: 2))
            case "train.reveal":
                train.results = Array(sample.prefix(3))
                train.step = .reveal(Reveal.State(result: sample[2], puttNumber: 3))
            case "train.summary":
                train.results = sample
                train.step = .summary(Summary.State(results: sample))
            default:
                break
            }
            var quickRead = QuickReadFeature.State(mode: .train(train))
            quickRead.hasCheckedPermission = true
            destination = .tool(ToolFeature.State(tool: .quickRead(quickRead)))
        case "tempo": destination = .tempo(TempoFeature.State())
        default: break
        }
    }
}
#endif
