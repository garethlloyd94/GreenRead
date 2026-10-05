import Foundation

/// One scored Train putt, as Stats sees it.
public struct StatsPutt: Equatable, Sendable {
    /// Rounds in play order: 0 is the oldest.
    public var roundIndex: Int
    public var distanceFeet: Double
    public var actualSlopePercent: Int
    public var actualBreak: BreakDirection
    public var actualHill: Hill
    public var guessedSlopePercent: Int

    public init(
        roundIndex: Int,
        distanceFeet: Double,
        actualSlopePercent: Int,
        actualBreak: BreakDirection,
        actualHill: Hill,
        guessedSlopePercent: Int
    ) {
        self.roundIndex = roundIndex
        self.distanceFeet = distanceFeet
        self.actualSlopePercent = actualSlopePercent
        self.actualBreak = actualBreak
        self.actualHill = actualHill
        self.guessedSlopePercent = guessedSlopePercent
    }

    /// Read error as a share of the real slope: −0.5 means half the break was missed.
    var relativeError: Double {
        Double(guessedSlopePercent - actualSlopePercent) / Double(max(1, actualSlopePercent))
    }
}

/// A Stats group and how far off the reads in it are.
public struct StatsBucket: Equatable, Sendable, Identifiable {
    public enum Group: String, CaseIterable, Sendable {
        case leftToRight, rightToLeft, uphill, downhill, gentle, steep, short, mid, long

        /// Bar label: "L → R", "3–4%", "20 ft+".
        public var label: String {
            switch self {
            case .leftToRight: "L → R"
            case .rightToLeft: "R → L"
            case .uphill: "Uphill"
            case .downhill: "Downhill"
            case .gentle: "1–2%"
            case .steep: "3–4%"
            case .short: "< 10 ft"
            case .mid: "10–20 ft"
            case .long: "20 ft+"
            }
        }

        /// Used in the insight sentence: "You under-read left-to-right putts…".
        public var phrase: String {
            switch self {
            case .leftToRight: "left-to-right"
            case .rightToLeft: "right-to-left"
            case .uphill: "uphill"
            case .downhill: "downhill"
            case .gentle: "gentle (1–2%)"
            case .steep: "steep (3–4%)"
            case .short: "short"
            case .mid: "mid-length"
            case .long: "long"
            }
        }

        func contains(_ putt: StatsPutt) -> Bool {
            switch self {
            case .leftToRight: putt.actualBreak == .leftToRight
            case .rightToLeft: putt.actualBreak == .rightToLeft
            case .uphill: putt.actualHill == .up
            case .downhill: putt.actualHill == .down
            case .gentle: putt.actualSlopePercent <= 2
            case .steep: putt.actualSlopePercent >= 3
            case .short: putt.distanceFeet < 10
            case .mid: putt.distanceFeet >= 10 && putt.distanceFeet < 20
            case .long: putt.distanceFeet >= 20
            }
        }
    }

    public let group: Group
    /// Average read error as a percentage of the real slope, clamped to ±50:
    /// negative under-read, positive over-read.
    public let biasPercent: Int
    public let puttCount: Int

    public var id: Group { group }
}

public enum StatsEngine {
    public static let roundsToUnlock = 3
    /// A group needs this many putts before it is shown or used in the insight.
    public static let minimumPutts = 2
    /// Bias smaller than this counts as balanced.
    public static let insightThreshold = 15
    /// How many of the latest rounds count as "recent" for the improving check.
    public static let recentRounds = 3

    /// Every group with enough putts, in display order.
    public static func buckets(_ putts: [StatsPutt]) -> [StatsBucket] {
        StatsBucket.Group.allCases.compactMap { group in
            let members = putts.filter(group.contains)
            guard members.count >= minimumPutts else { return nil }
            return StatsBucket(group: group, biasPercent: bias(members), puttCount: members.count)
        }
    }

    /// The headline on the insight card (decision Q16).
    public static func insight(_ putts: [StatsPutt]) -> String {
        let buckets = buckets(putts)
        // Ties go to the group listed first.
        let worst = buckets.reduce(nil as StatsBucket?) { best, bucket in
            abs(bucket.biasPercent) > abs(best?.biasPercent ?? -1) ? bucket : best
        }
        if let worst, abs(worst.biasPercent) >= insightThreshold {
            let direction = worst.biasPercent < 0 ? "under-read" : "over-read"
            return "You \(direction) \(worst.group.phrase) putts by about \(abs(worst.biasPercent))%"
        }
        if let improving = mostImproved(putts) {
            return "Your \(improving.phrase) reads are improving"
        }
        return "Your reads are well balanced"
    }

    /// The group whose average miss shrank most between earlier and recent rounds.
    static func mostImproved(_ putts: [StatsPutt]) -> StatsBucket.Group? {
        guard let latest = putts.map(\.roundIndex).max() else { return nil }
        let cutoff = latest - recentRounds + 1
        var best: (group: StatsBucket.Group, gain: Double)?
        for group in StatsBucket.Group.allCases {
            let members = putts.filter(group.contains)
            let earlier = members.filter { $0.roundIndex < cutoff }
            let recent = members.filter { $0.roundIndex >= cutoff }
            guard earlier.count >= minimumPutts, recent.count >= minimumPutts else { continue }
            let gain = meanMiss(earlier) - meanMiss(recent)
            if gain >= 0.1, gain > (best?.gain ?? 0) {
                best = (group, gain)
            }
        }
        return best?.group
    }

    private static func bias(_ putts: [StatsPutt]) -> Int {
        let mean = putts.reduce(0) { $0 + $1.relativeError } / Double(putts.count)
        return min(50, max(-50, Int((mean * 100).rounded())))
    }

    private static func meanMiss(_ putts: [StatsPutt]) -> Double {
        putts.reduce(0) { $0 + abs($1.relativeError) } / Double(putts.count)
    }
}
