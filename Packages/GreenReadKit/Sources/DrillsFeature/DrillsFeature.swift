import ComposableArchitecture
import DesignSystem
import Models
import SQLiteData
import SwiftUI
import TempoFeature

public enum DrillFilter: Hashable, Sendable {
    case all
    case saved
    case category(DrillCategory)

    public static var allFilters: [Self] { [.all, .saved] + DrillCategory.allCases.map(Self.category) }

    public var title: String {
        switch self {
        case .all: "All"
        case .saved: "Saved"
        case let .category(category): category.title
        }
    }
}

/// Home's Drills segment: category chips and video rows with a ♥ save toggle.
@Reducer
public struct DrillsFeed {
    @ObservableState
    public struct State: Equatable {
        public var drills: [Drill] = []
        public var filter: DrillFilter = .all
        @ObservationStateIgnored
        @FetchAll(SavedVideo.order { $0.savedAt.desc() }) public var savedVideos

        public init() {}

        public var savedIDs: Set<String> { Set(savedVideos.map(\.id)) }

        public var visibleDrills: [Drill] {
            switch filter {
            case .all:
                return drills
            case .saved:
                return savedVideos.compactMap { saved in drills.first { $0.id == saved.id } }
            case let .category(category):
                return drills.filter { $0.category == category }
            }
        }
    }

    public enum Action {
        case delegate(Delegate)
        case filterTapped(DrillFilter)
        case saveToggled(id: String)
        case task
        case videoTapped(id: String)

        @CasePathable
        public enum Delegate {
            case openPlayer(Drill, upNext: [Drill])
        }
    }

    @Dependency(DrillCatalogClient.self) var catalog
    @Dependency(\.date.now) var now
    @Dependency(\.defaultDatabase) var database

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none

            case let .filterTapped(filter):
                state.filter = filter
                return .none

            case let .saveToggled(id):
                return toggleSaved(id: id, isSaved: state.savedIDs.contains(id), now: now, database: database)

            case .task:
                guard state.drills.isEmpty else { return .none }
                state.drills = (try? catalog.load()) ?? []
                return .none

            case let .videoTapped(id):
                guard let drill = state.drills.first(where: { $0.id == id }) else { return .none }
                let upNext = state.drills.filter { $0.id != id }
                return .send(.delegate(.openPlayer(drill, upNext: upNext)))
            }
        }
    }
}

/// Saves or unsaves a video. Shared by the feed and the player.
func toggleSaved<Action>(id: String, isSaved: Bool, now: Date, database: any DatabaseWriter) -> Effect<Action> {
    .run { _ in
        try await database.write { db in
            if isSaved {
                try SavedVideo.find(id).delete().execute(db)
            } else {
                try SavedVideo.insert {
                    SavedVideo(id: id, savedAt: now)
                } onConflictDoUpdate: {
                    $0.savedAt = $1.savedAt
                }
                .execute(db)
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
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(DrillFilter.allFilters, id: \.self) { filter in
                        Chip(title: filter.title, isSelected: store.filter == filter) {
                            store.send(.filterTapped(filter))
                        }
                    }
                }
                .padding(.horizontal, GRMetrics.screenPadding)
            }
            .padding(.horizontal, -GRMetrics.screenPadding)

            let saved = store.savedIDs
            ForEach(store.visibleDrills) { drill in
                VideoRow(
                    title: drill.title,
                    subtitle: drill.subtitle,
                    duration: drill.duration,
                    isSaved: saved.contains(drill.id),
                    onOpen: { store.send(.videoTapped(id: drill.id)) },
                    onToggleSave: { store.send(.saveToggled(id: drill.id)) }
                )
            }
            if store.visibleDrills.isEmpty {
                Text(store.filter == .saved ? "Nothing saved yet — tap ♡ on any video." : "No videos here yet.")
                    .grFont(.archivo(15, weight: 600))
                    .foregroundStyle(GRColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            }
        }
        .task { await store.send(.task).finish() }
    }
}

// MARK: - Player

/// In-app player (D1), pushed full-screen: embed, Save, Start tempo, Up next.
@Reducer
public struct PlayerFeature {
    @ObservableState
    public struct State: Equatable {
        public var drill: Drill
        public var upNext: [Drill]
        @ObservationStateIgnored
        @FetchAll(SavedVideo.all) public var savedVideos
        @Presents public var tempo: TempoFeature.State?

        public init(drill: Drill, upNext: [Drill] = []) {
            self.drill = drill
            self.upNext = upNext
        }

        public var isSaved: Bool { savedVideos.contains { $0.id == drill.id } }
    }

    public enum Action {
        case backButtonTapped
        case saveButtonTapped
        case startTempoButtonTapped
        case tempo(PresentationAction<TempoFeature.Action>)
        case upNextTapped(id: String)
    }

    @Dependency(\.date.now) var now
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped:
                return .run { [dismiss] _ in await dismiss() }

            case .saveButtonTapped:
                return toggleSaved(id: state.drill.id, isSaved: state.isSaved, now: now, database: database)

            case .startTempoButtonTapped:
                state.tempo = TempoFeature.State()
                return .none

            case .tempo:
                return .none

            case let .upNextTapped(id):
                guard let next = state.upNext.first(where: { $0.id == id }) else { return .none }
                state.upNext.removeAll { $0.id == id }
                state.upNext.append(state.drill)
                state.drill = next
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
        let drill = store.drill
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CircleIconButton(systemName: "chevron.left", accessibilityLabel: "Back", size: 46) {
                    store.send(.backButtonTapped)
                }
                .padding(.horizontal, GRMetrics.screenPadding)
                .padding(.vertical, 4)

                Group {
                    if let youtubeID = drill.youtubeID {
                        YouTubePlayer(videoID: youtubeID)
                    } else {
                        ZStack {
                            StripedPlaceholder(dark: GRColor.videoDark, light: GRColor.videoLight, stripe: 10)
                            Image(systemName: "play.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(GRColor.ink)
                                .frame(width: 64, height: 64)
                                .background(Circle().fill(.white))
                            Text("VIDEO COMING SOON")
                                .gr(.labelSmall)
                                .foregroundStyle(GRColor.textMuted)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(12)
                        }
                        .accessibilityElement()
                        .accessibilityLabel("Video coming soon")
                    }
                }
                .frame(height: 220)
                .id(drill.id)

                Text(drill.title)
                    .grFont(.archivo(22, weight: 800))
                    .padding(.top, 18)
                    .padding(.horizontal, GRMetrics.screenPadding)
                Text("\(drill.creator) · \(drill.duration) · \(drill.category.title)")
                    .grFont(.archivo(14, weight: 600))
                    .foregroundStyle(GRColor.textSecondary)
                    .padding(.top, 6)
                    .padding(.horizontal, GRMetrics.screenPadding)

                HStack(spacing: 8) {
                    PillButton(store.isSaved ? "♥ Saved" : "♡ Save", kind: .neutral, height: 52) {
                        store.send(.saveButtonTapped)
                    }
                    PillButton("Start tempo", kind: .secondary, height: 52) {
                        store.send(.startTempoButtonTapped)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, GRMetrics.screenPadding)

                if !store.upNext.isEmpty {
                    Text("UP NEXT").gr(.label).foregroundStyle(GRColor.textSecondary)
                        .padding(.top, 24)
                        .padding(.horizontal, GRMetrics.screenPadding)
                    VStack(spacing: 10) {
                        ForEach(store.upNext.prefix(3)) { next in
                            Button {
                                store.send(.upNextTapped(id: next.id))
                            } label: {
                                UpNextRow(drill: next)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, GRMetrics.screenPadding)
                }
            }
            .padding(.bottom, 24)
        }
        .foregroundStyle(GRColor.ink)
        .background(GRColor.chalk.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $store.scope(state: \.tempo, action: \.tempo)) { tempoStore in
            TempoView(store: tempoStore)
        }
    }
}

/// Compact Up next row: thumbnail with duration, title and subtitle.
private struct UpNextRow: View {
    let drill: Drill

    var body: some View {
        HStack(spacing: 12) {
            StripedPlaceholder()
                .frame(width: 96, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Text(drill.duration)
                        .grFont(.archivo(11, weight: 700))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 6).fill(GRColor.ink))
                        .padding(5)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(drill.title).grFont(.archivo(15, weight: 700))
                Text(drill.subtitle).grFont(.archivo(12, weight: 500)).foregroundStyle(GRColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(GRColor.card))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
