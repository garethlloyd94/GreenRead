import ComposableArchitecture
import DesignSystem
import DrillsFeature
import Models
import SQLiteData
import SwiftUI

/// Home (navigation option Nd): wordmark, Play | Drills switch and ⚙, then the Play tiles.
@Reducer
public struct HomeFeature {
    @ObservableState
    public struct State: Equatable {
        public var drills = DrillsFeed.State()
        public var segment: Segment = .play
        @ObservationStateIgnored
        @Fetch(StatsSummary.Request()) public var stats = StatsSummary()
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
            VStack(alignment: .leading, spacing: 0) {
                Wordmark()
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                HStack(spacing: GRMetrics.gap) {
                    PillSegmentedControl(
                        options: HomeFeature.Segment.allCases,
                        selection: $store.segment
                    ) { $0.rawValue }
                    CircleIconButton(systemName: "gearshape.fill", accessibilityLabel: "Settings", size: 46) {
                        store.send(.settingsButtonTapped)
                    }
                }
                .padding(.horizontal, GRMetrics.screenPadding)
                .padding(.top, 18)
                switch store.segment {
                case .play:
                    playTiles
                        .padding(GRMetrics.screenPadding)
                case .drills:
                    DrillsFeedView(store: store.scope(state: \.drills, action: \.drills))
                        .padding(GRMetrics.screenPadding)
                }
            }
        }
        .background(GRColor.chalk.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var playTiles: some View {
        VStack(spacing: 12) {
            HomeTile(title: "Scan", subtitle: "AR putt line on the green", height: 132, isHero: true) {
                store.send(.scanTileTapped)
            }
            HomeTile(title: "Quick Read", subtitle: "Phone flat · Read or Train", height: 132) {
                store.send(.quickReadTileTapped)
            }
            HomeTile(title: "Tempo", subtitle: "Metronome · \(store.tempoBPM) BPM", height: 112, titleSize: 24) {
                store.send(.tempoTileTapped)
            }
            StatsTile(hint: store.stats.hint) {
                store.send(.statsTileTapped)
            }
            #if DEBUG
            NavigationLink("Component gallery") { ComponentGallery() }
                .grTextStyle(.headline)
                .frame(minHeight: GRMetrics.minTapTarget)
            #endif
        }
    }
}

/// Large Play tile: title, subtitle and a › chevron. Scan is the green hero.
private struct HomeTile: View {
    let title: String
    let subtitle: String
    let height: CGFloat
    var isHero = false
    var titleSize: CGFloat = 26
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(GRFont.archivo(titleSize, weight: 800))
                    Text(subtitle)
                        .font(GRFont.archivo(14, weight: 500))
                        .foregroundStyle(isHero ? Color.white : GRColor.textSecondary)
                }
                Spacer()
                Text("›").font(GRFont.archivo(26, weight: 800))
            }
            .foregroundStyle(isHero ? Color.white : GRColor.ink)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: GRMetrics.largeCardRadius, style: .continuous)
                    .fill(isHero ? GRColor.green : GRColor.card)
            )
            .contentShape(RoundedRectangle(cornerRadius: GRMetrics.largeCardRadius, style: .continuous))
        }
        .buttonStyle(TilePressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Compact Stats tile: "2/3 rounds ›" until Stats unlock, then the accuracy figure.
private struct StatsTile: View {
    let hint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("Stats").font(GRFont.archivo(19, weight: 800))
                Spacer()
                Text("\(hint) ›")
                    .font(GRFont.archivo(14, weight: 700))
                    .foregroundStyle(GRColor.green)
            }
            .foregroundStyle(GRColor.ink)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(
                RoundedRectangle(cornerRadius: GRMetrics.largeCardRadius, style: .continuous)
                    .fill(GRColor.card)
            )
            .contentShape(RoundedRectangle(cornerRadius: GRMetrics.largeCardRadius, style: .continuous))
        }
        .buttonStyle(TilePressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

private struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    let _ = prepareDependencies { try! $0.bootstrapDatabase() }
    NavigationStack {
        HomeView(store: Store(initialState: HomeFeature.State()) { HomeFeature() })
    }
}
