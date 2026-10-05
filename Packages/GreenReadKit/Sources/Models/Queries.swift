import Foundation
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
