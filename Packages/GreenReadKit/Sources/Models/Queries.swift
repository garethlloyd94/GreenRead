import Foundation
import GreenReadCore
import SQLiteData

/// Rounds played and the recent accuracy figure, for the Home Stats tile and Stats.
public struct StatsSummary: Equatable, Sendable {
    public var roundCount = 0
    /// Average score of the most recent rounds, out of 100. `nil` until a round is played.
    public var recentAccuracy: Int?

    public static let roundsToUnlock = 3
    public static let recentRoundLimit = 7

    public init(roundCount: Int = 0, recentAccuracy: Int? = nil) {
        self.roundCount = roundCount
        self.recentAccuracy = recentAccuracy
    }

    public var isUnlocked: Bool { roundCount >= Self.roundsToUnlock }

    /// "2/3 rounds" until Stats unlock, then the accuracy figure ("71%").
    public var hint: String {
        if isUnlocked, let recentAccuracy {
            return "\(recentAccuracy)%"
        }
        return "\(min(roundCount, Self.roundsToUnlock))/\(Self.roundsToUnlock) rounds"
    }

    public struct Request: FetchKeyRequest {
        public init() {}

        public func fetch(_ db: Database) throws -> StatsSummary {
            let roundCount = try TrainRound.all.fetchCount(db)
            let recentScores = try TrainRound
                .order { $0.playedAt.desc() }
                .limit(StatsSummary.recentRoundLimit)
                .select(\.score)
                .fetchAll(db)
            let accuracy = recentScores.isEmpty
                ? nil
                : Int((Double(recentScores.reduce(0, +)) / Double(recentScores.count)).rounded())
            return StatsSummary(roundCount: roundCount, recentAccuracy: accuracy)
        }
    }
}

/// Everything the Stats screen shows: progress to unlock, the breakdown and the trend.
public struct StatsReport: Equatable, Sendable {
    public var summary = StatsSummary()
    /// Every Train putt, with rounds numbered oldest first.
    public var putts: [StatsPutt] = []
    /// Scores of the most recent rounds, oldest first.
    public var recentScores: [Int] = []

    public init(summary: StatsSummary = StatsSummary(), putts: [StatsPutt] = [], recentScores: [Int] = []) {
        self.summary = summary
        self.putts = putts
        self.recentScores = recentScores
    }

    public var buckets: [StatsBucket] { StatsEngine.buckets(putts) }
    public var insight: String { StatsEngine.insight(putts) }

    public struct Request: FetchKeyRequest {
        public init() {}

        public func fetch(_ db: Database) throws -> StatsReport {
            let rounds = try TrainRound.order(by: \.playedAt).fetchAll(db)
            let roundIndex = Dictionary(uniqueKeysWithValues: rounds.enumerated().map { ($1.id, $0) })
            let putts = try TrainPutt.order(by: \.position).fetchAll(db).compactMap { putt -> StatsPutt? in
                guard let index = roundIndex[putt.trainRoundID] else { return nil }
                let actual = SlopeReading(uphillPercent: putt.actualUphillPercent, sidePercent: putt.actualSidePercent)
                return StatsPutt(
                    roundIndex: index,
                    distanceFeet: putt.distanceFeet,
                    actualSlopePercent: TrainScoring.scoredSlope(actual),
                    actualBreak: actual.breakDirection,
                    actualHill: actual.hill,
                    guessedSlopePercent: putt.guessedSlopePercent
                )
            }
            return StatsReport(
                summary: try StatsSummary.Request().fetch(db),
                putts: putts,
                recentScores: rounds.suffix(StatsSummary.recentRoundLimit).map(\.score)
            )
        }
    }
}
