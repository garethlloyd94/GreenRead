import Foundation
import GreenReadCore
import SQLiteData

/// One five-putt Train round.
@Table public struct TrainRound: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var playedAt: Date
    /// Score out of 100.
    public var score: Int

    public init(id: UUID, playedAt: Date, score: Int) {
        self.id = id
        self.playedAt = playedAt
        self.score = score
    }
}

/// One putt in a Train round: the golfer's guess, the measured slope and the verdict.
@Table public struct TrainPutt: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var trainRoundID: TrainRound.ID
    /// 1–5, in the order the putts were played.
    public var position: Int
    public var distanceFeet: Double
    public var actualUphillPercent: Double
    public var actualSidePercent: Double
    public var guessedSlopePercent: Int
    public var guessedBreak: BreakDirection
    public var guessedHill: Hill
    public var guessedAimInches: Int
    public var verdict: Verdict
    public var points: Int

    public init(
        id: UUID,
        trainRoundID: TrainRound.ID,
        position: Int,
        distanceFeet: Double,
        actualUphillPercent: Double,
        actualSidePercent: Double,
        guessedSlopePercent: Int,
        guessedBreak: BreakDirection,
        guessedHill: Hill,
        guessedAimInches: Int,
        verdict: Verdict,
        points: Int
    ) {
        self.id = id
        self.trainRoundID = trainRoundID
        self.position = position
        self.distanceFeet = distanceFeet
        self.actualUphillPercent = actualUphillPercent
        self.actualSidePercent = actualSidePercent
        self.guessedSlopePercent = guessedSlopePercent
        self.guessedBreak = guessedBreak
        self.guessedHill = guessedHill
        self.guessedAimInches = guessedAimInches
        self.verdict = verdict
        self.points = points
    }
}

/// A Quick Read or Scan result the golfer saved.
@Table public struct SavedRead: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var savedAt: Date
    public var source: Source
    public var distanceFeet: Double
    public var uphillPercent: Double
    public var sidePercent: Double
    public var stimp: Double
    public var aimInches: Int

    public enum Source: String, QueryBindable, Sendable {
        case quickRead, scan
    }

    public init(
        id: UUID,
        savedAt: Date,
        source: Source,
        distanceFeet: Double,
        uphillPercent: Double,
        sidePercent: Double,
        stimp: Double,
        aimInches: Int
    ) {
        self.id = id
        self.savedAt = savedAt
        self.source = source
        self.distanceFeet = distanceFeet
        self.uphillPercent = uphillPercent
        self.sidePercent = sidePercent
        self.stimp = stimp
        self.aimInches = aimInches
    }
}

/// A drill video the golfer hearted. `id` is the catalogue's video ID.
@Table public struct SavedVideo: Identifiable, Equatable, Sendable {
    public let id: String
    public var savedAt: Date

    public init(id: String, savedAt: Date) {
        self.id = id
        self.savedAt = savedAt
    }
}

extension BreakDirection: @retroactive QueryBindable {}
extension Hill: @retroactive QueryBindable {}
extension Verdict: @retroactive QueryBindable {}
