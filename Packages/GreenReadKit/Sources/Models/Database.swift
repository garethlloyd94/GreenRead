import Dependencies
import Foundation
import OSLog
import SQLiteData

extension DependencyValues {
    /// Opens the on-device database and runs migrations. Call once from `prepareDependencies`
    /// at launch, and from the `.dependencies` trait in previews and tests.
    public mutating func bootstrapDatabase() throws {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        configuration.prepareDatabase { [context] db in
            db.add(function: $uuid)
            #if DEBUG
            db.trace(options: .profile) {
                guard !$0.expandedDescription.hasPrefix("--") else { return }
                switch context {
                case .live:
                    logger.debug("\($0.expandedDescription)")
                case .preview:
                    print("\($0.expandedDescription)")
                case .test:
                    break
                }
            }
            #endif
        }
        let database = try SQLiteData.defaultDatabase(configuration: configuration)
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        migrator.registerMigration("Create 'trainRounds', 'trainPutts', 'savedReads' and 'savedVideos' tables") { db in
            try #sql("""
                CREATE TABLE "trainRounds" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "playedAt" TEXT NOT NULL,
                  "score" INTEGER NOT NULL
                ) STRICT
                """)
                .execute(db)
            try #sql("""
                CREATE TABLE "trainPutts" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "trainRoundID" TEXT NOT NULL REFERENCES "trainRounds"("id") ON DELETE CASCADE,
                  "position" INTEGER NOT NULL,
                  "distanceFeet" REAL NOT NULL,
                  "actualUphillPercent" REAL NOT NULL,
                  "actualSidePercent" REAL NOT NULL,
                  "guessedSlopePercent" INTEGER NOT NULL,
                  "guessedBreak" TEXT NOT NULL,
                  "guessedHill" TEXT NOT NULL,
                  "guessedAimInches" INTEGER NOT NULL,
                  "verdict" TEXT NOT NULL,
                  "points" INTEGER NOT NULL
                ) STRICT
                """)
                .execute(db)
            try #sql("""
                CREATE INDEX "index_trainPutts_on_trainRoundID" ON "trainPutts"("trainRoundID")
                """)
                .execute(db)
            try #sql("""
                CREATE TABLE "savedReads" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "savedAt" TEXT NOT NULL,
                  "source" TEXT NOT NULL,
                  "distanceFeet" REAL NOT NULL,
                  "uphillPercent" REAL NOT NULL,
                  "sidePercent" REAL NOT NULL,
                  "stimp" REAL NOT NULL,
                  "aimInches" INTEGER NOT NULL
                ) STRICT
                """)
                .execute(db)
            try #sql("""
                CREATE TABLE "savedVideos" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "savedAt" TEXT NOT NULL
                ) STRICT
                """)
                .execute(db)
        }
        try migrator.migrate(database)
        defaultDatabase = database
    }
}

/// `uuid()` in SQL, routed through `@Dependency(\.uuid)` so tests get predictable IDs.
@DatabaseFunction nonisolated func uuid() -> UUID {
    @Dependency(\.uuid) var uuid
    return uuid()
}

private let logger = Logger(subsystem: "com.garethlloyd.greenread", category: "Database")

#if DEBUG
extension Database {
    /// Four Train rounds with a clear under-read on left-to-right putts, for checking Stats.
    public func seedSampleRounds() throws {
        let scores = [52, 61, 58, 71]
        let base = Date(timeIntervalSince1970: 1_790_000_000)
        try seed {
            for (index, score) in scores.enumerated() {
                let roundID = UUID(-(index + 1))
                TrainRound(id: roundID, playedAt: base.addingTimeInterval(Double(index) * 86_400), score: score)
                for position in 1...5 {
                    let leftToRight = position.isMultiple(of: 2)
                    TrainPutt(
                        id: UUID(-(index * 5 + position)),
                        trainRoundID: roundID,
                        position: position,
                        distanceFeet: Double(6 + position * 4),
                        actualUphillPercent: position == 3 ? -1.4 : 1.1,
                        actualSidePercent: leftToRight ? -3 : 2,
                        guessedSlopePercent: leftToRight ? 2 : 2,
                        guessedBreak: leftToRight ? .leftToRight : .rightToLeft,
                        guessedHill: .up,
                        guessedAimInches: 10,
                        verdict: leftToRight ? .underRead : .spotOn,
                        points: leftToRight ? 12 : 20
                    )
                }
            }
        }
    }
}
#endif
