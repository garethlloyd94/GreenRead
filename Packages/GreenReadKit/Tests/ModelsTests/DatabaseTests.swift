import CustomDump
import DependenciesTestSupport
import Foundation
import GreenReadCore
import SQLiteData
import Testing

@testable import Models

@Suite(
    .dependencies {
        $0.date.now = Date(timeIntervalSince1970: 1_791_000_000)
        $0.uuid = .incrementing
        try $0.bootstrapDatabase()
    }
)
struct DatabaseTests {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.date.now) var now

    @Test func roundsAndPuttsRoundTrip() throws {
        try database.write { db in
            try TrainRound.insert {
                TrainRound.Draft(playedAt: now, score: 79)
            }
            .execute(db)
            try TrainPutt.insert {
                TrainPutt.Draft(
                    trainRoundID: UUID(0),
                    position: 1,
                    distanceFeet: 15,
                    actualUphillPercent: 1.2,
                    actualSidePercent: 2.1,
                    guessedSlopePercent: 1,
                    guessedBreak: .rightToLeft,
                    guessedHill: .up,
                    guessedAimInches: 8,
                    verdict: .underRead,
                    points: 12
                )
            }
            .execute(db)
        }

        let (rounds, putts) = try database.read { db in
            (try TrainRound.all.fetchAll(db), try TrainPutt.all.fetchAll(db))
        }
        expectNoDifference(rounds, [TrainRound(id: UUID(0), playedAt: now, score: 79)])
        expectNoDifference(putts.map(\.verdict), [.underRead])
        expectNoDifference(putts.map(\.guessedBreak), [.rightToLeft])
    }

    @Test func deletingARoundDeletesItsPutts() throws {
        try database.write { db in
            try db.seed {
                TrainRound(id: UUID(-1), playedAt: now, score: 50)
                TrainPutt(
                    id: UUID(-1),
                    trainRoundID: UUID(-1),
                    position: 1,
                    distanceFeet: 8,
                    actualUphillPercent: 0,
                    actualSidePercent: -1,
                    guessedSlopePercent: 1,
                    guessedBreak: .leftToRight,
                    guessedHill: .flat,
                    guessedAimInches: 3,
                    verdict: .spotOn,
                    points: 20
                )
            }
            try TrainRound.find(UUID(-1)).delete().execute(db)
        }

        let puttCount = try database.read { db in try TrainPutt.all.fetchCount(db) }
        #expect(puttCount == 0)
    }

    @Test func savedVideosAreKeyedByVideoID() throws {
        try database.write { db in
            try SavedVideo.insert { SavedVideo(id: "abc123", savedAt: now) }.execute(db)
            try SavedVideo.insert {
                SavedVideo(id: "abc123", savedAt: now)
            } onConflictDoUpdate: {
                $0.savedAt = $1.savedAt
            }
            .execute(db)
        }

        let count = try database.read { db in try SavedVideo.all.fetchCount(db) }
        #expect(count == 1)
    }
}

@Suite(
    .dependencies {
        $0.uuid = .incrementing
        try $0.bootstrapDatabase()
    }
)
struct StatsSummaryTests {
    @Dependency(\.defaultDatabase) var database

    @Test func showsRoundsUntilUnlockedThenRecentAccuracy() throws {
        let empty = try database.read { db in try StatsSummary.Request().fetch(db) }
        expectNoDifference(empty, StatsSummary(roundCount: 0, recentAccuracy: nil))
        #expect(empty.hint == "0/3 rounds")

        try database.write { db in
            try db.seed {
                TrainRound(id: UUID(-1), playedAt: Date(timeIntervalSince1970: 1), score: 60)
                TrainRound(id: UUID(-2), playedAt: Date(timeIntervalSince1970: 2), score: 71)
            }
        }
        let two = try database.read { db in try StatsSummary.Request().fetch(db) }
        #expect(two.hint == "2/3 rounds")

        try database.write { db in
            try db.seed {
                TrainRound(id: UUID(-3), playedAt: Date(timeIntervalSince1970: 3), score: 82)
            }
        }
        let three = try database.read { db in try StatsSummary.Request().fetch(db) }
        expectNoDifference(three, StatsSummary(roundCount: 3, recentAccuracy: 71))
        #expect(three.hint == "71%")
    }

    @Test func accuracyUsesTheSevenMostRecentRounds() throws {
        try database.write { db in
            try db.seed {
                TrainRound(id: UUID(-1), playedAt: Date(timeIntervalSince1970: 0), score: 0)
                for index in 1...7 {
                    TrainRound(id: UUID(-1 - index), playedAt: Date(timeIntervalSince1970: Double(index)), score: 80)
                }
            }
        }
        let summary = try database.read { db in try StatsSummary.Request().fetch(db) }
        expectNoDifference(summary, StatsSummary(roundCount: 8, recentAccuracy: 80))
    }
}
