import SwiftUI

/// Temporary root for M0 + M1: the wordmark and, in debug builds, the component gallery.
/// M2 replaces this with Home (Play | Drills) and onboarding.
struct RootView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Wordmark()
                Text("Home arrives in the next milestone.")
                    .gr(.body)
                    .foregroundStyle(GRColor.textSecondary)
                #if DEBUG
                NavigationLink {
                    ComponentGallery()
                } label: {
                    Text("Open component gallery")
                        .gr(.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: GRMetrics.primaryButtonHeight)
                        .background(Capsule().fill(GRColor.ink))
                }
                .buttonStyle(.plain)
                #endif
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GRColor.chalk.ignoresSafeArea())
        }
    }
}

#Preview {
    RootView()
}
