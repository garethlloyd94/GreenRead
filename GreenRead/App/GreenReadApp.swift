import AppFeature
import Clients
import ComposableArchitecture
import DesignSystem
import Models
import OSLog
import SwiftUI

@main
struct GreenReadApp: App {
    @MainActor static let store = Store(initialState: initialState()) {
        AppFeature()
    }

    private static let logger = Logger(subsystem: "com.garethlloyd.greenread", category: "App")

    init() {
        prepareDependencies {
            do {
                try $0.bootstrapDatabase()
            } catch {
                // Keep the app usable for this launch; saved rounds and reads won't persist.
                Self.logger.fault("Couldn't open the database, using an in-memory one: \(String(describing: error))")
                try! $0.bootstrapDatabase(inMemory: true)
            }
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
        var state = AppFeature.State.launch()
        #if DEBUG
        if let screen = UserDefaults.standard.string(forKey: "screen") {
            state.openForDebugging(screen)
        }
        #endif
        return state
    }
}
