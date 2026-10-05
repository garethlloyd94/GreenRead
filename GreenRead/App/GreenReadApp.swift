import AppFeature
import ComposableArchitecture
import DesignSystem
import Models
import OSLog
import SwiftUI

@main
struct GreenReadApp: App {
    @MainActor static let store = Store(initialState: AppFeature.State.launch()) {
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
        }
        GRFont.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
                .preferredColorScheme(.light)
        }
    }
}
