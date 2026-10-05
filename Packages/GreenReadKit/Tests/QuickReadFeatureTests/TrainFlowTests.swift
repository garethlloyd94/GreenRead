import Clients
import ComposableArchitecture
import CustomDump
import DependenciesTestSupport
import Foundation
import GreenReadCore
import Models
import SQLiteData
import Testing

@testable import QuickReadFeature

@Suite(
    .dependencies {
        $0.date.now = Date(timeIntervalSince1970: 1_791_000_000)
        $0.uuid = .incrementing
        try $0.bootstrapDatabase()
    }
)
@MainActor
struct TrainFlowTests {
    @Test func lockInNeedsSlopeBreakAndHill() async {
        let store = TestStore(initialState: Guess.State(feet: 15, puttIndex: 0)) { Guess() }

        await store.send(.lockInButtonTapped)
        await store.send(.binding(.set(\.slopePercent, 2))) { $0.slopePercent = 2 }
        await store.send(.binding(.set(\.breakDirection, .rightToLeft))) { $0.breakDirection = .rightToLeft }
        await store.send(.lockInButtonTapped)
        await store.send(.binding(.set(\.hill, .up))) { $0.hill = .up }
        await store.send(.aimPlusTapped) { $0.aimInches = 13 }
        await store.send(.lockInButtonTapped)
        await store.receive(\.delegate.locked)
    }

    @Test func onePuttGoesMeasureGuessHiddenLayFlatReveal() async {
        var measure = Measure.State()
        measure.method = .manual
        var state = TrainFlow.State()
        state.step = .measure(measure)
        let store = TestStore(initialState: state) {
            TrainFlow()
        } withDependencies: {
            $0[MotionClient.self].attitudeUpdates = { stillPhone(uphill: 1.2, side: 3.2) }
        }

        await store.send(\.step.measure.nextButtonTapped)
        await store.receive(\.step.measure.delegate.measured) {
            $0.feet = 15
            $0.step = .guess(Guess.State(feet: 15, puttIndex: 0))
        }
        await store.send(\.step.guess.binding, .set(\.slopePercent, 2)) {
            $0.step.modify(\.guess) { $0.slopePercent = 2 }
        }
        await store.send(\.step.guess.binding, .set(\.breakDirection, .rightToLeft)) {
            $0.step.modify(\.guess) { $0.breakDirection = .rightToLeft }
        }
        await store.send(\.step.guess.binding, .set(\.hill, .up)) {
            $0.step.modify(\.guess) { $0.hill = .up }
        }
        await store.send(\.step.guess.lockInButtonTapped)
        await store.receive(\.step.guess.delegate.locked) {
            $0.guess = TrainGuess(slopePercent: 2, breakDirection: .rightToLeft, hill: .up, aimInches: 12)
            $0.step = .layFlat(LayFlat.State(hidesNumbers: true))
        }

        store.exhaustivity = .off
        await store.send(\.step.layFlat.task)
        await store.receive(\.step.layFlat.delegate.finished, timeout: .seconds(5))
        store.exhaustivity = .on

        #expect(store.state.results.count == 1)
        let result = store.state.results[0]
        // 3.2% rounds to 3: guessed 2 → under-read by 1 → 12 points.
        #expect(result.score.verdict == .underRead)
        #expect(result.score.points == 12)
        #expect(store.state.step.reveal?.puttNumber == 1)

        await store.send(\.step.reveal.nextButtonTapped)
        await store.receive(\.step.reveal.delegate.next) {
            $0.feet = nil
            $0.guess = nil
            $0.step = .measure(Measure.State())
        }
    }

    @Test func fifthPuttShowsSummaryAndSavesTheRound() async throws {
        let results = (0..<5).map { index in
            Self.result(feet: Double(8 + index), guessed: 2, side: index.isMultiple(of: 2) ? 2 : 3)
        }
        var state = TrainFlow.State()
        state.results = results
        state.step = .reveal(Reveal.State(result: results[4], puttNumber: 5))
        let store = TestStore(initialState: state) { TrainFlow() }

        await store.send(\.step.reveal.nextButtonTapped)
        await store.receive(\.step.reveal.delegate.next) {
            $0.step = .summary(Summary.State(results: results))
        }
        await store.finish()

        let summary = try #require(store.state.step.summary)
        // Three spot on (20) and two under-read by 1 (12).
        #expect(summary.score == 84)
        #expect(summary.tendency == "You tend to under-read — trust more break.")

        @Dependency(\.defaultDatabase) var database
        let (rounds, puttCount) = try await database.read { db in
            (try TrainRound.all.fetchAll(db), try TrainPutt.all.fetchCount(db))
        }
        expectNoDifference(rounds.map(\.score), [84])
        #expect(puttCount == 5)

        await store.send(\.step.summary.playAgainButtonTapped)
        await store.receive(\.step.summary.delegate.playAgain) {
            $0 = TrainFlow.State()
        }
    }

    private static func result(feet: Double, guessed: Int, side: Double) -> TrainPuttResult {
        let guess = TrainGuess(slopePercent: guessed, breakDirection: .rightToLeft, hill: .up, aimInches: 12)
        let actual = SlopeReading(uphillPercent: 1, sidePercent: side)
        return TrainPuttResult(
            feet: feet,
            guess: guess,
            actual: actual,
            actualAimInches: TourRead.read(feet: feet, slope: actual).aimInches,
            score: TrainScoring.score(guess: guess, actual: actual)
        )
    }
}

/// A phone that is tilted for a moment, then lies still on the given slope.
func stillPhone(uphill: Double, side: Double) -> AsyncStream<AttitudeSample> {
    AsyncStream { continuation in
        var time = 0.0
        while time < 0.3 {
            continuation.yield(AttitudeSample(time: time, pitch: 0.4, roll: 0.1))
            time += 1.0 / 60
        }
        while time < 2.6 {
            continuation.yield(AttitudeSample(time: time, pitch: atan(uphill / 100), roll: -atan(side / 100)))
            time += 1.0 / 60
        }
        continuation.finish()
    }
}
