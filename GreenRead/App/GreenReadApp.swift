import AppFeature
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
        }
        GRFont.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
                .preferredColorScheme(.light)
        }
    }

    /// In debug builds, `-screen settings|tempo|quickRead|scan|stats` opens that screen at launch,
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
