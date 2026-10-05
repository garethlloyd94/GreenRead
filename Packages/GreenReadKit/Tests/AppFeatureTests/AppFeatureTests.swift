import ComposableArchitecture
import DependenciesTestSupport
import Testing

@testable import AppFeature
@testable import DrillsFeature
@testable import HomeFeature
@testable import OnboardingFeature
@testable import QuickReadFeature
@testable import ScanFeature
@testable import SettingsFeature
@testable import StatsFeature
@testable import TempoFeature
@testable import ToolFeature

@Suite(
    .dependencies {
        try $0.bootstrapDatabase()
    }
)
@MainActor
struct AppFeatureTests {
    @Test func firstLaunchShowsOnboarding() async {
        let store = TestStore(initialState: AppFeature.State.launch()) {
            AppFeature()
        }
        #expect(store.state.destination == .onboarding(OnboardingFeature.State()))

        await store.send(\.destination.onboarding.getStartedButtonTapped) { _ in
            @Shared(.hasSeenOnboarding) var hasSeenOnboarding
            $hasSeenOnboarding.withLock { $0 = true }
        }
        await store.receive(\.destination.dismiss) {
            $0.destination = nil
        }
        #expect(AppFeature.State.launch().destination == nil)
    }

    @Test func homeTilesOpenEachDestination() async {
        let store = TestStore(initialState: Self.returningUser()) {
            AppFeature()
        }

        await store.send(\.home.scanTileTapped)
        await store.receive(\.home.delegate.openScan) {
            $0.destination = .tool(.scan)
        }
        await store.send(\.destination.dismiss) {
            $0.destination = nil
        }

        await store.send(\.home.quickReadTileTapped)
        await store.receive(\.home.delegate.openQuickRead) {
            $0.destination = .tool(.quickRead)
        }
        await store.send(\.destination.dismiss) {
            $0.destination = nil
        }

        await store.send(\.home.tempoTileTapped)
        await store.receive(\.home.delegate.openTempo) {
            $0.destination = .tempo(TempoFeature.State())
        }
        await store.send(\.destination.dismiss) {
            $0.destination = nil
        }

        await store.send(\.home.settingsButtonTapped)
        await store.receive(\.home.delegate.openSettings) {
            $0.destination = .settings(SettingsFeature.State())
        }
        await store.send(\.destination.dismiss) {
            $0.destination = nil
        }

        await store.send(\.home.statsTileTapped)
        await store.receive(\.home.delegate.openStats) {
            $0.path[id: 0] = .stats(StatsFeature.State())
        }
    }

    @Test func toolCloseButtonDismisses() async {
        var state = Self.returningUser()
        state.destination = .tool(.scan)
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(\.destination.tool.closeButtonTapped)
        await store.receive(\.destination.dismiss) {
            $0.destination = nil
        }
    }

    @Test func switcherSwapsTools() async {
        var state = Self.returningUser()
        state.destination = .tool(.scan)
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(\.destination.tool.switcherTapped, .quickRead) {
            $0.destination = .tool(.quickRead)
        }
        await store.send(\.destination.tool.switcherTapped, .quickRead)
        await store.send(\.destination.tool.switcherTapped, .scan) {
            $0.destination = .tool(.scan)
        }
    }

    @Test func noLiDARFallbackSwitchesToQuickRead() async {
        var state = Self.returningUser()
        state.destination = .tool(.scan)
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(\.destination.tool.tool.scan.useQuickReadButtonTapped)
        await store.receive(\.destination.tool.tool.scan.delegate.switchToQuickRead) {
            $0.destination = .tool(.quickRead)
        }
    }

    @Test func trainSummaryShowsStats() async {
        var train = TrainFlow.State()
        train.step = .summary(Summary.State(results: []))
        var state = Self.returningUser()
        state.destination = .tool(ToolFeature.State(tool: .quickRead(QuickReadFeature.State(mode: .train(train)))))
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(\.destination.tool.tool.quickRead.mode.train.step.summary.statsButtonTapped)
        await store.receive(\.destination.tool.tool.quickRead.mode.train.step.summary.delegate.showStats)
        await store.receive(\.destination.tool.tool.quickRead.mode.train.delegate.showStats)
        await store.receive(\.destination.tool.tool.quickRead.delegate.showStats)
        await store.receive(\.destination.tool.delegate.showStats) {
            $0.destination = nil
            $0.path[id: 0] = .stats(StatsFeature.State())
        }
    }

    @Test func lockedStatsStartsATrainRound() async {
        var state = Self.returningUser()
        state.path.append(.stats(StatsFeature.State()))
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(\.path[id: 0].stats.playTrainRoundButtonTapped)
        await store.receive(\.path[id: 0].stats.delegate.playTrainRound) {
            $0.path = StackState()
            $0.destination = .tool(
                ToolFeature.State(tool: .quickRead(QuickReadFeature.State(mode: .train(TrainFlow.State()))))
            )
        }
    }

    @Test func readTrainSwitch() async {
        var state = Self.returningUser()
        state.destination = .tool(.quickRead)
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(\.destination.tool.tool.quickRead.modeChanged, .train) {
            $0.destination = .tool(ToolFeature.State(tool: .quickRead(QuickReadFeature.State(mode: .train(TrainFlow.State())))))
        }
        await store.send(\.destination.tool.tool.quickRead.modeChanged, .read) {
            $0.destination = .tool(.quickRead)
        }
    }

    @Test func drillOpensPlayerAndPlayerOpensTempo() async {
        let drills = [
            Drill(id: "a", title: "A", creator: "C", category: .tempo, duration: "1:00"),
            Drill(id: "b", title: "B", creator: "C", category: .alignment, duration: "2:00"),
        ]
        var state = Self.returningUser()
        state.home.drills.drills = drills
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(\.home.drills.videoTapped, "a")
        await store.receive(\.home.drills.delegate.openPlayer)
        await store.receive(\.home.delegate.openPlayer) {
            $0.path[id: 0] = .player(PlayerFeature.State(drill: drills[0], upNext: [drills[1]]))
        }
        await store.send(\.path[id: 0].player.startTempoButtonTapped) {
            $0.path[id: 0, case: \.player]?.tempo = TempoFeature.State()
        }
    }

    private static func returningUser() -> AppFeature.State {
        @Shared(.hasSeenOnboarding) var hasSeenOnboarding
        $hasSeenOnboarding.withLock { $0 = true }
        return .launch()
    }
}
