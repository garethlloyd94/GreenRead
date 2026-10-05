import ComposableArchitecture
import DesignSystem
import SwiftUI
import TempoFeature

/// Home's Drills segment. The catalogue, chips and saving arrive in M6.
@Reducer
public struct DrillsFeed {
    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action {
        case delegate(Delegate)
        case videoTapped(id: String)

        @CasePathable
        public enum Delegate {
            case openPlayer(videoID: String)
        }
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none

            case let .videoTapped(id):
                return .send(.delegate(.openPlayer(videoID: id)))
            }
        }
    }
}

public struct DrillsFeedView: View {
    let store: StoreOf<DrillsFeed>

    public init(store: StoreOf<DrillsFeed>) {
        self.store = store
    }

    public var body: some View {
        VideoRow(
            title: "Read the low side first",
            subtitle: "Placeholder · Green reading",
            duration: "4:12",
            isSaved: false,
            onOpen: { store.send(.videoTapped(id: "placeholder-1")) },
            onToggleSave: {}
        )
    }
}

/// In-app video player, pushed full-screen. The YouTube embed arrives in M6.
@Reducer
public struct PlayerFeature {
    @ObservableState
    public struct State: Equatable {
        public var videoID: String
        @Presents public var tempo: TempoFeature.State?

        public init(videoID: String) {
            self.videoID = videoID
        }
    }

    public enum Action {
        case startTempoButtonTapped
        case tempo(PresentationAction<TempoFeature.Action>)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startTempoButtonTapped:
                state.tempo = TempoFeature.State()
                return .none

            case .tempo:
                return .none
            }
        }
        .ifLet(\.$tempo, action: \.tempo) {
            TempoFeature()
        }
    }
}

public struct PlayerView: View {
    @Bindable var store: StoreOf<PlayerFeature>

    public init(store: StoreOf<PlayerFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 16) {
            StripedPlaceholder()
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: GRMetrics.cardRadius, style: .continuous))
            Text(store.videoID).gr(.label).foregroundStyle(GRColor.textSecondary)
            PillButton("Start tempo", kind: .neutral) {
                store.send(.startTempoButtonTapped)
            }
            Spacer()
        }
        .padding(GRMetrics.screenPadding)
        .background(GRColor.chalk)
        .sheet(item: $store.scope(state: \.tempo, action: \.tempo)) { tempoStore in
            TempoView(store: tempoStore)
        }
    }
}

#Preview {
    NavigationStack {
        PlayerView(store: Store(initialState: PlayerFeature.State(videoID: "placeholder-1")) { PlayerFeature() })
    }
}
