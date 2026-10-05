import ComposableArchitecture
import DesignSystem
import Models
import SQLiteData
import SwiftUI

/// Stats, pushed from Home or from the Train summary. Insights and the trend chart land in M4.
@Reducer
public struct StatsFeature {
    @ObservableState
    public struct State: Equatable {
        @ObservationStateIgnored
        @FetchOne(TrainRound.count()) public var roundCount = 0

        public init() {}
    }

    public enum Action {}

    public init() {}

    public var body: some Reducer<State, Action> {
        EmptyReducer()
    }
}

public struct StatsView: View {
    let store: StoreOf<StatsFeature>

    public init(store: StoreOf<StatsFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats").gr(.title)
            Text("\(min(store.roundCount, 3))/3 rounds")
                .gr(.body)
                .foregroundStyle(GRColor.textSecondary)
            Spacer()
        }
        .padding(GRMetrics.screenPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GRColor.chalk.ignoresSafeArea())
    }
}

#Preview {
    let _ = prepareDependencies { try! $0.bootstrapDatabase() }
    NavigationStack {
        StatsView(store: Store(initialState: StatsFeature.State()) { StatsFeature() })
    }
}
