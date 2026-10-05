import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Models
import SQLiteData
import Testing

@testable import DrillsFeature

@Suite(
    .dependencies {
        $0.date.now = Date(timeIntervalSince1970: 1_791_000_000)
        try $0.bootstrapDatabase()
    }
)
@MainActor
struct DrillsFeatureTests {
    @Test func bundledCatalogueLoads() throws {
        let drills = try DrillCatalogClient.liveValue.load()
        #expect(drills.count == 6)
        #expect(Set(drills.map(\.category)) == Set(DrillCategory.allCases))
    }

    @Test func chipsFilterByCategoryAndSaved() async throws {
        let store = TestStore(initialState: DrillsFeed.State()) {
            DrillsFeed()
        } withDependencies: {
            $0[DrillCatalogClient.self] = .liveValue
        }

        await store.send(.task) {
            $0.drills = try! DrillCatalogClient.liveValue.load()
        }
        await store.send(.filterTapped(.category(.greenReading))) {
            $0.filter = .category(.greenReading)
        }
        #expect(store.state.visibleDrills.map(\.id) == ["double-breakers", "bigger-break"])

        await store.send(.filterTapped(.saved)) { $0.filter = .saved }
        #expect(store.state.visibleDrills.isEmpty)

        await store.send(.saveToggled(id: "lag-ladder"))
        await store.finish()
        try await store.state.$savedVideos.load()
        #expect(store.state.visibleDrills.map(\.id) == ["lag-ladder"])

        await store.send(.saveToggled(id: "lag-ladder"))
        await store.finish()
        try await store.state.$savedVideos.load()
        #expect(store.state.visibleDrills.isEmpty)
    }

    @Test func tappingAVideoOpensThePlayerWithTheRestAsUpNext() async {
        var state = DrillsFeed.State()
        state.drills = try! DrillCatalogClient.liveValue.load()
        let store = TestStore(initialState: state) { DrillsFeed() }

        await store.send(.videoTapped(id: "tempo-76"))
        await store.receive(\.delegate.openPlayer)
    }

    @Test func upNextSwapsTheVideoInPlace() async {
        let drills = try! DrillCatalogClient.liveValue.load()
        let store = TestStore(initialState: PlayerFeature.State(drill: drills[0], upNext: Array(drills[1...2]))) {
            PlayerFeature()
        }

        await store.send(.upNextTapped(id: drills[2].id)) {
            $0.drill = drills[2]
            $0.upNext = [drills[1], drills[0]]
        }
    }
}
