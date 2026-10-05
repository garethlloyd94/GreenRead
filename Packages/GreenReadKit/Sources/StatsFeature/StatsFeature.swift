import Charts
import ComposableArchitecture
import DesignSystem
import GreenReadCore
import Models
import SQLiteData
import SwiftUI

/// Stats (design 9a + the 9b trend): locked until 3 Train rounds, then the insight,
/// under/over breakdown and accuracy over the last 7 rounds.
@Reducer
public struct StatsFeature {
    @ObservableState
    public struct State: Equatable {
        @ObservationStateIgnored
        @Fetch(StatsReport.Request()) public var report = StatsReport()

        public init() {}
    }

    public enum Action {
        case backButtonTapped
        case delegate(Delegate)
        case playTrainRoundButtonTapped

        @CasePathable
        public enum Delegate {
            case playTrainRound
        }
    }

    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .backButtonTapped:
                return .run { [dismiss] _ in await dismiss() }

            case .delegate:
                return .none

            case .playTrainRoundButtonTapped:
                return .send(.delegate(.playTrainRound))
            }
        }
    }
}

public struct StatsView: View {
    let store: StoreOf<StatsFeature>

    public init(store: StoreOf<StatsFeature>) {
        self.store = store
    }

    public var body: some View {
        let report = store.report
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    CircleIconButton(systemName: "chevron.left", accessibilityLabel: "Back", size: 46) {
                        store.send(.backButtonTapped)
                    }
                    Text("Stats").font(GRFont.archivo(26, weight: 800))
                }
                .padding(.top, 4)

                if report.summary.isUnlocked {
                    InsightCard(eyebrow: "INSIGHT · \(report.summary.roundCount) ROUNDS", headline: report.insight)
                    breakdown(report.buckets)
                    trend(report.recentScores)
                } else {
                    locked(report.summary.roundCount)
                }
            }
            .padding(.horizontal, GRMetrics.screenPadding)
            .padding(.bottom, 24)
        }
        .foregroundStyle(GRColor.ink)
        .background(GRColor.chalk.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func locked(_ rounds: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(0..<StatsSummary.roundsToUnlock, id: \.self) { index in
                    Capsule()
                        .fill(index < rounds ? GRColor.green : GRColor.border)
                        .frame(height: 10)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(min(rounds, StatsSummary.roundsToUnlock)) of \(StatsSummary.roundsToUnlock) rounds played")
            Text("Play 3 rounds to unlock your insights")
                .font(GRFont.archivo(24, weight: 800))
            Text("\(rounds) of 3 done. We'll show where you over- and under-read.")
                .font(GRFont.archivo(14, weight: 400))
                .foregroundStyle(GRColor.textSecondary)
            PillButton("Play a Train round", height: 54) { store.send(.playTrainRoundButtonTapped) }
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(GRColor.card))
        .padding(.top, 6)
    }

    private func breakdown(_ buckets: [StatsBucket]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DivergingBarLegend()
            ForEach(buckets) { bucket in
                DivergingBar(label: bucket.group.label, value: Double(bucket.biasPercent) / 100)
                    .accessibilityElement()
                    .accessibilityLabel(bucket.group.label)
                    .accessibilityValue(accessibilityValue(bucket))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(GRColor.card))
    }

    private func trend(_ scores: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ACCURACY · LAST \(scores.count) ROUNDS").gr(.label).foregroundStyle(GRColor.textSecondary)
                Spacer()
                if let last = scores.last {
                    Text("\(last)").font(GRFont.archivo(20, weight: 800))
                }
            }
            Chart(Array(scores.enumerated()), id: \.offset) { index, score in
                LineMark(x: .value("Round", index + 1), y: .value("Score", score))
                    .foregroundStyle(GRColor.green)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Round", index + 1), y: .value("Score", score))
                    .foregroundStyle(GRColor.green)
                    .symbolSize(index == scores.count - 1 ? 90 : 36)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { _ in
                    AxisGridLine().foregroundStyle(GRColor.fill)
                    AxisValueLabel().font(GRFont.mono(10)).foregroundStyle(GRColor.textMuted)
                }
            }
            .frame(height: 140)
            .accessibilityLabel("Round scores")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(GRColor.card))
    }

    private func accessibilityValue(_ bucket: StatsBucket) -> String {
        if bucket.biasPercent < 0 { return "Under-read by \(-bucket.biasPercent)%" }
        if bucket.biasPercent > 0 { return "Over-read by \(bucket.biasPercent)%" }
        return "Balanced"
    }
}

#Preview {
    let _ = prepareDependencies { try! $0.bootstrapDatabase() }
    NavigationStack {
        StatsView(store: Store(initialState: StatsFeature.State()) { StatsFeature() })
    }
}
