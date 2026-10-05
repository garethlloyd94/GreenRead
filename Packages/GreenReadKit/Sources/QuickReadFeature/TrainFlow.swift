import ComposableArchitecture
import DesignSystem
import GreenReadCore
import Models
import SQLiteData
import SwiftUI

/// One played Train putt.
public struct TrainPuttResult: Equatable, Sendable {
    public init(feet: Double, guess: TrainGuess, actual: SlopeReading, actualAimInches: Int, score: PuttScore) {
        self.feet = feet
        self.guess = guess
        self.actual = actual
        self.actualAimInches = actualAimInches
        self.score = score
    }

    public var feet: Double
    public var guess: TrainGuess
    public var actual: SlopeReading
    public var actualAimInches: Int
    public var score: PuttScore
}

/// Train mode: five putts of Measure → Guess → Lay flat (hidden) → Reveal, then the summary.
@Reducer
public struct TrainFlow {
    @ObservableState
    public struct State: Equatable {
        public var guess: TrainGuess?
        public var feet: Double?
        public var results: [TrainPuttResult] = []
        public var step: Step.State = .measure(Measure.State())
        @SharedReader(.appSettings) public var settings

        public init() {}

        public var puttIndex: Int { results.count }
    }

    @Reducer
    public enum Step {
        case guess(Guess)
        case layFlat(LayFlat)
        case measure(Measure)
        case reveal(Reveal)
        case summary(Summary)
    }

    public enum Action {
        case delegate(Delegate)
        case step(Step.Action)

        @CasePathable
        public enum Delegate {
            case showStats
        }
    }

    @Dependency(\.date.now) var now
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some Reducer<State, Action> {
        Scope(state: \.step, action: \.step) {
            Step.body
        }
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none

            case let .step(.measure(.delegate(.measured(feet)))):
                state.feet = feet
                state.step = .guess(Guess.State(feet: feet, puttIndex: state.puttIndex))
                return .none

            case let .step(.guess(.delegate(.locked(guess)))):
                state.guess = guess
                state.step = .layFlat(LayFlat.State(hidesNumbers: true))
                return .none

            case let .step(.layFlat(.delegate(.finished(reading)))):
                guard let feet = state.feet, let guess = state.guess else { return .none }
                let result = TrainPuttResult(
                    feet: feet,
                    guess: guess,
                    actual: reading,
                    actualAimInches: TourRead.read(feet: feet, slope: reading, speed: state.settings.defaultSpeed).aimInches,
                    score: TrainScoring.score(guess: guess, actual: reading)
                )
                state.results.append(result)
                state.step = .reveal(
                    Reveal.State(result: result, puttNumber: state.results.count)
                )
                return .none

            case .step(.reveal(.delegate(.next))):
                state.feet = nil
                state.guess = nil
                guard state.results.count >= TrainScoring.puttsPerRound else {
                    state.step = .measure(Measure.State())
                    return .none
                }
                state.step = .summary(Summary.State(results: state.results))
                return saveRound(state.results)

            case .step(.summary(.delegate(.playAgain))):
                state = State()
                return .none

            case .step(.summary(.delegate(.showStats))):
                return .send(.delegate(.showStats))

            case .step:
                return .none
            }
        }
    }

    private func saveRound(_ results: [TrainPuttResult]) -> Effect<Action> {
        let round = TrainRound(id: uuid(), playedAt: now, score: results.reduce(0) { $0 + $1.score.points })
        let putts = results.enumerated().map { index, result in
            TrainPutt(
                id: uuid(),
                trainRoundID: round.id,
                position: index + 1,
                distanceFeet: result.feet,
                actualUphillPercent: result.actual.uphillPercent,
                actualSidePercent: result.actual.sidePercent,
                guessedSlopePercent: result.guess.slopePercent,
                guessedBreak: result.guess.breakDirection,
                guessedHill: result.guess.hill,
                guessedAimInches: result.guess.aimInches,
                verdict: result.score.verdict,
                points: result.score.points
            )
        }
        return .run { [database] _ in
            try await database.write { db in
                try TrainRound.insert { round }.execute(db)
                try TrainPutt.insert { putts }.execute(db)
            }
        }
    }
}

extension TrainFlow.Step.State: Equatable {}

#if DEBUG
extension TrainFlow {
    /// The prototype's five putts with a mix of verdicts, for layout checks.
    public static var debugSamples: [TrainPuttResult] {
        let putts: [(Double, Int, BreakDirection, Hill, Double)] = [
            (8, 1, .leftToRight, .up, -1.1),
            (12, 2, .leftToRight, .flat, -3.1),
            (15, 2, .leftToRight, .up, 2.9),
            (20, 3, .rightToLeft, .down, 2.2),
            (6, 2, .leftToRight, .down, -1.8),
        ]
        return putts.map { feet, guessed, direction, hill, side in
            let guess = TrainGuess(slopePercent: guessed, breakDirection: direction, hill: hill, aimInches: 12)
            let actual = SlopeReading(uphillPercent: hill == .up ? 1.2 : hill == .down ? -1.2 : 0, sidePercent: side)
            return TrainPuttResult(
                feet: feet,
                guess: guess,
                actual: actual,
                actualAimInches: TourRead.read(feet: feet, slope: actual).aimInches,
                score: TrainScoring.score(guess: guess, actual: actual)
            )
        }
    }
}
#endif

// MARK: - Reveal

/// Train reveal (design 7a): verdict banner, then You vs Actual.
@Reducer
public struct Reveal {
    @ObservableState
    public struct State: Equatable {
        public var result: TrainPuttResult
        /// 1-based number of the putt being revealed.
        public var puttNumber: Int
        @SharedReader(.appSettings) public var settings

        public init(result: TrainPuttResult, puttNumber: Int) {
            self.result = result
            self.puttNumber = puttNumber
        }

        public var isLastPutt: Bool { puttNumber >= TrainScoring.puttsPerRound }
    }

    public enum Action {
        case delegate(Delegate)
        case nextButtonTapped

        @CasePathable
        public enum Delegate {
            case next
        }
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .delegate:
                return .none
            case .nextButtonTapped:
                return .send(.delegate(.next))
            }
        }
    }
}

struct RevealView: View {
    let store: StoreOf<Reveal>

    var body: some View {
        let result = store.result
        let actualSlope = result.score.actualSlopePercent
        let actualBreak = result.actual.breakDirection
        let actualHill = result.actual.hill
        VStack(spacing: 12) {
            VerdictBanner(
                verdict: result.score.verdict,
                detail: "You read \(result.guess.slopePercent)%, it was \(actualSlope)%"
            )
            HStack(alignment: .top, spacing: 8) {
                RevealColumn(
                    title: "YOU",
                    headline: "\(result.guess.slopePercent)%",
                    rows: [
                        RevealColumn.Row(text: result.guess.breakDirection.label),
                        RevealColumn.Row(text: result.guess.hill.label),
                        RevealColumn.Row(text: store.settings.aim(inches: result.guess.aimInches).amount),
                    ]
                )
                RevealColumn(
                    title: "ACTUAL",
                    headline: "\(actualSlope)%",
                    headlineMismatch: result.guess.slopePercent != actualSlope,
                    rows: [
                        RevealColumn.Row(text: actualBreak.label, mismatch: result.guess.breakDirection != actualBreak),
                        RevealColumn.Row(text: actualHill.label, mismatch: result.guess.hill != actualHill),
                        RevealColumn.Row(
                            text: store.settings.aim(inches: result.actualAimInches).amount,
                            mismatch: result.guess.aimInches != result.actualAimInches
                        ),
                    ],
                    isActual: true
                )
            }
            Spacer()
            PillButton(nextLabel, kind: .neutral) { store.send(.nextButtonTapped) }
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 116)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GRColor.chalk.ignoresSafeArea())
        .sensoryFeedback(result.score.verdict == .spotOn ? .success : .warning, trigger: result.score.verdict) { _, _ in
            store.settings.hapticsOn
        }
    }

    private var nextLabel: String {
        store.isLastPutt
            ? "See round summary"
            : "Next putt · \(store.puttNumber + 1)/\(TrainScoring.puttsPerRound)"
    }
}

// MARK: - Summary

/// Round summary (design 8a): score /100, per-putt verdicts, tendency, Stats / Play again.
@Reducer
public struct Summary {
    @ObservableState
    public struct State: Equatable {
        public var results: [TrainPuttResult]
        @SharedReader(.appSettings) public var settings

        public init(results: [TrainPuttResult]) {
            self.results = results
        }

        public var score: Int { results.reduce(0) { $0 + $1.score.points } }
        public var tendency: String { TrainScoring.tendency(signedErrors: results.map(\.score.signedSlopeError)) }
    }

    public enum Action {
        case delegate(Delegate)
        case playAgainButtonTapped
        case statsButtonTapped

        @CasePathable
        public enum Delegate {
            case playAgain
            case showStats
        }
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .delegate:
                return .none
            case .playAgainButtonTapped:
                return .send(.delegate(.playAgain))
            case .statsButtonTapped:
                return .send(.delegate(.showStats))
            }
        }
    }
}

struct SummaryView: View {
    let store: StoreOf<Summary>

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 10) {
                Text("\(store.score)")
                    .grFont(.archivo(72, weight: 800, width: 115))
                    .tracking(72 * -0.03)
                    .popIn(trigger: store.score)
                Text("/100\nround score")
                    .grFont(.archivo(14, weight: 600))
                    .foregroundStyle(GRColor.textSecondary)
                    .padding(.bottom, 10)
                Spacer()
            }
            .padding(.horizontal, 4)
            .accessibilityElement(children: .combine)

            VStack(spacing: 0) {
                ForEach(Array(store.results.enumerated()), id: \.offset) { index, result in
                    HStack {
                        Text("\(index + 1) · \(store.settings.distance(feet: result.feet)) \(result.actual.breakDirection.label)")
                        Spacer()
                        Text(result.score.verdict.title)
                            .fontWeight(.heavy)
                            .foregroundStyle(result.score.verdict.colour)
                    }
                    .grFont(.archivo(15, weight: 600))
                    .frame(height: 46)
                    .overlay(alignment: .bottom) {
                        if index < store.results.count - 1 {
                            Rectangle().fill(GRColor.fill).frame(height: 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(GRColor.card))

            Text(store.tendency)
                .grFont(.archivo(15, weight: 700))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(GRColor.ink))

            Spacer()
            HStack(spacing: 8) {
                PillButton("Stats", kind: .secondary) { store.send(.statsButtonTapped) }
                PillButton("Play again") { store.send(.playAgainButtonTapped) }
            }
            .padding(.bottom, 8)
        }
        .foregroundStyle(GRColor.ink)
        .padding(.horizontal, 16)
        .padding(.top, 116)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GRColor.chalk.ignoresSafeArea())
    }
}

// MARK: - Flow view

struct TrainFlowView: View {
    let store: StoreOf<TrainFlow>

    var body: some View {
        switch store.scope(state: \.step, action: \.step).case {
        case let .measure(measureStore):
            MeasureView(
                store: measureStore,
                title: "PUTT \(store.puttIndex + 1) OF \(TrainScoring.puttsPerRound)",
                nextLabel: "Next · make your read"
            )
        case let .guess(guessStore):
            GuessView(store: guessStore)
        case let .layFlat(layFlatStore):
            LayFlatView(store: layFlatStore)
        case let .reveal(revealStore):
            RevealView(store: revealStore)
        case let .summary(summaryStore):
            SummaryView(store: summaryStore)
        }
    }
}
