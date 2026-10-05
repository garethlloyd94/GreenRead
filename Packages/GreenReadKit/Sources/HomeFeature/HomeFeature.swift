import ComposableArchitecture
import DesignSystem
import DrillsFeature
import Models
import SwiftUI

/// Home (navigation option Nd): wordmark, Play | Drills switch and ⚙. Tiles are styled in M2.
@Reducer
public struct HomeFeature {
    @ObservableState
    public struct State: Equatable {
        public var drills = DrillsFeed.State()
        public var segment: Segment = .play
        @SharedReader(.tempoBPM) public var tempoBPM

        public init() {}
    }

    public enum Segment: String, CaseIterable, Sendable {
        case play = "Play"
        case drills = "Drills"
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case drills(DrillsFeed.Action)
        case quickReadTileTapped
        case scanTileTapped
        case settingsButtonTapped
        case statsTileTapped
        case tempoTileTapped

        @CasePathable
        public enum Delegate {
            case openPlayer(videoID: String)
            case openQuickRead
            case openScan
            case openSettings
            case openStats
            case openTempo
        }
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Scope(state: \.drills, action: \.drills) {
            DrillsFeed()
        }
        Reduce { state, action in
            switch action {
            case .binding, .delegate:
                return .none

            case let .drills(.delegate(.openPlayer(videoID))):
                return .send(.delegate(.openPlayer(videoID: videoID)))

            case .drills:
                return .none

            case .quickReadTileTapped:
                return .send(.delegate(.openQuickRead))

            case .scanTileTapped:
                return .send(.delegate(.openScan))

            case .settingsButtonTapped:
                return .send(.delegate(.openSettings))

            case .statsTileTapped:
                return .send(.delegate(.openStats))

            case .tempoTileTapped:
                return .send(.delegate(.openTempo))
            }
        }
    }
}

public struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Wordmark()
                HStack(spacing: GRMetrics.gap) {
                    PillSegmentedControl(
                        options: HomeFeature.Segment.allCases,
                        selection: $store.segment
                    ) { $0.rawValue }
                    CircleIconButton(systemName: "gearshape", accessibilityLabel: "Settings", size: 46) {
                        store.send(.settingsButtonTapped)
                    }
                }
                switch store.segment {
                case .play:
                    playTiles
                case .drills:
                    DrillsFeedView(store: store.scope(state: \.drills, action: \.drills))
                }
            }
            .padding(.horizontal, GRMetrics.screenPadding)
            .padding(.top, 12)
        }
        .background(GRColor.chalk.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var playTiles: some View {
        VStack(spacing: GRMetrics.gap) {
            PillButton("Scan", kind: .go) { store.send(.scanTileTapped) }
            PillButton("Quick Read", kind: .neutral) { store.send(.quickReadTileTapped) }
            PillButton("Tempo · \(store.tempoBPM) BPM", kind: .secondary) { store.send(.tempoTileTapped) }
            PillButton("Stats", kind: .secondary) { store.send(.statsTileTapped) }
            #if DEBUG
            NavigationLink("Component gallery") { ComponentGallery() }
                .grTextStyle(.headline)
                .frame(minHeight: GRMetrics.minTapTarget)
            #endif
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(store: Store(initialState: HomeFeature.State()) { HomeFeature() })
    }
}
