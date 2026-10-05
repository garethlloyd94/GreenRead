import Dependencies
import Foundation
import OSLog
import SQLiteData

extension DependencyValues {
    /// Opens the on-device database and runs migrations. Call once from `prepareDependencies`
    /// at launch, and from the `.dependencies` trait in previews and tests.
    ///
    /// - Parameter inMemory: Use a throwaway in-memory database instead of the file on disk.
    ///   The app falls back to this when the file can't be opened or migrated.
    public mutating func bootstrapDatabase(inMemory: Bool = false) throws {
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
        let database: any DatabaseWriter
        if inMemory {
            database = try DatabaseQueue(configuration: configuration)
        } else {
            database = try SQLiteData.defaultDatabase(configuration: configuration)
        }
        var migrator = DatabaseMigrator()
        #if DEBUG
        // Debug builds wipe the database whenever the schema or a migration changes. Release
        // builds never do: once a migration ships, add a new one instead of editing it.
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        // Migration names are stored in the database for good, so keep them short and stable.
        // v1: trainRounds, trainPutts, savedReads and savedVideos.
        migrator.registerMigration("v1") { db in
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
