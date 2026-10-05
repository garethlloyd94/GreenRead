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

    @Test func savedReadsRoundTrip() throws {
        try database.write { db in
            try SavedRead.insert {
                SavedRead.Draft(
                    savedAt: now,
                    source: .quickRead,
                    distanceFeet: 15,
                    uphillPercent: 1.2,
                    sidePercent: 2.1,
                    stimp: 10,
                    aimInches: 16
                )
                SavedRead.Draft(
                    savedAt: now,
                    source: .scan,
                    distanceFeet: 20,
                    uphillPercent: -2,
                    sidePercent: -1,
                    stimp: 12,
                    aimInches: 15
                )
            }
            .execute(db)
        }

        let reads = try database.read { db in try SavedRead.order(by: \.distanceFeet).fetchAll(db) }
        expectNoDifference(
            reads,
            [
                SavedRead(
                    id: UUID(0),
                    savedAt: now,
                    source: .quickRead,
                    distanceFeet: 15,
                    uphillPercent: 1.2,
                    sidePercent: 2.1,
                    stimp: 10,
                    aimInches: 16
                ),
                SavedRead(
                    id: UUID(1),
                    savedAt: now,
                    source: .scan,
                    distanceFeet: 20,
                    uphillPercent: -2,
                    sidePercent: -1,
                    stimp: 12,
                    aimInches: 15
                ),
            ]
        )
    }
}
