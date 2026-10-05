import AppFeature
import ComposableArchitecture
import DesignSystem
import Models
import SwiftUI

@main
struct GreenReadApp: App {
    @MainActor static let store = Store(initialState: AppFeature.State()) {
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
}
