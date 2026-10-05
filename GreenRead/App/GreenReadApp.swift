import AppFeature
import Clients
import ComposableArchitecture
import DesignSystem
import Models
import SwiftUI

@main
struct GreenReadApp: App {
    @MainActor static let store = Store(initialState: initialState()) {
        AppFeature()
    }

    init() {
        prepareDependencies {
            try! $0.bootstrapDatabase()
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "seedStats") {
                try? $0.defaultDatabase.write { try $0.seedSampleRounds() }
            }
            #endif
            #if DEBUG && targetEnvironment(simulator)
            // The Simulator has no motion sensors: script a phone being laid on a green.
            $0[MotionClient.self] = .previewValue
            $0[PedometerClient.self] = .previewValue
            #endif
        }
        GRFont.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
                .preferredColorScheme(.light)
        }
    }

    /// In debug builds, `-screen <name>` opens a screen at launch (see `openForDebugging`),
    /// for checking layouts in the Simulator.
    private static func initialState() -> AppFeature.State {
        var state = AppFeature.State()
        #if DEBUG
        if let screen = UserDefaults.standard.string(forKey: "screen") {
            state.openForDebugging(screen)
        }
        #endif
        return state
    }
}
