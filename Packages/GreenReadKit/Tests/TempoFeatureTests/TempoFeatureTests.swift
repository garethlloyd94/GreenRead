import Clients
import ComposableArchitecture
import DependenciesTestSupport
import Models
import Testing

@testable import TempoFeature

@MainActor
struct TempoFeatureTests {
    @Test(.dependencies) func startPlaysBeatsUntilStopped() async {
        let (beats, continuation) = AsyncStream<TempoBeat>.makeStream()
        let startedWith = LockIsolated<TempoOptions?>(nil)
        let store = TestStore(initialState: TempoFeature.State()) {
            TempoFeature()
        } withDependencies: {
            $0[TempoClient.self].beats = { options in
                startedWith.setValue(options)
                return beats
            }
        }

        await store.send(.startStopButtonTapped) { $0.isPlaying = true }
        #expect(startedWith.value == TempoOptions(bpm: 76, soundsOn: true, hapticsOn: true))

        continuation.yield(TempoBeat(index: 0))
        await store.receive(\.beat) { $0.lastBeat = TempoBeat(index: 0) }
        continuation.yield(TempoBeat(index: 1))
        await store.receive(\.beat) { $0.lastBeat = TempoBeat(index: 1) }
        #expect(store.state.lastBeat?.kind == .through)

        await store.send(.startStopButtonTapped) {
            $0.isPlaying = false
            $0.lastBeat = nil
        }
    }

    @Test(.dependencies) func changingBPMWhilePlayingRetunesTheEngine() async {
        let (beats, _) = AsyncStream<TempoBeat>.makeStream()
        let retuned = LockIsolated<[Int]>([])
        let store = TestStore(initialState: TempoFeature.State()) {
            TempoFeature()
        } withDependencies: {
            $0[TempoClient.self].beats = { _ in beats }
            $0[TempoClient.self].setBPM = { bpm in retuned.withValue { $0.append(bpm) } }
        }

        await store.send(.plusButtonTapped) { $0.$bpm.withLock { $0 = 77 } }
        #expect(retuned.value == [])

        await store.send(.startStopButtonTapped) { $0.isPlaying = true }
        await store.send(.plusButtonTapped) { $0.$bpm.withLock { $0 = 78 } }
        await store.send(.minusButtonTapped) { $0.$bpm.withLock { $0 = 77 } }
        await store.send(.startStopButtonTapped) { $0.isPlaying = false }
        #expect(retuned.value == [78, 77])
    }

    @Test(.dependencies) func soundOffStartsHapticsOnly() async {
        @Shared(.appSettings) var settings
        $settings.withLock { $0.soundsOn = false }
        let startedWith = LockIsolated<TempoOptions?>(nil)
        let store = TestStore(initialState: TempoFeature.State()) {
            TempoFeature()
        } withDependencies: {
            $0[TempoClient.self].beats = { options in
                startedWith.setValue(options)
                return .finished
            }
        }

        await store.send(.startStopButtonTapped) { $0.isPlaying = true }
        await store.receive(\.stopped) { $0.isPlaying = false }
        #expect(startedWith.value == TempoOptions(bpm: 76, soundsOn: false, hapticsOn: true))
    }

    @Test(.dependencies) func bpmStopsAtTheEndsOfTheRange() async {
        @Shared(.tempoBPM) var bpm
        $bpm.withLock { $0 = 100 }
        let store = TestStore(initialState: TempoFeature.State()) { TempoFeature() }

        await store.send(.plusButtonTapped)
        $bpm.withLock { $0 = 60 }
        await store.send(.minusButtonTapped)
    }
}
