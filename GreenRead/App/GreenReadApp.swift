import SwiftData
import SwiftUI

@main
struct GreenReadApp: App {
    init() {
        GRFont.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
                .tint(GRColor.green)
        }
        .modelContainer(for: [AppSettings.self])
    }
}
