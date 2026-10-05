import SwiftUI

/// Result numbers "pop" in: scale 0.6 → 1.06 → 1 with a fade, 0.4 s.
/// Re-runs whenever `trigger` changes.
public struct PopIn<Trigger: Equatable>: ViewModifier {
    public let trigger: Trigger

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 1

    public func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear(perform: run)
            .onChange(of: trigger) { _, _ in run() }
    }

    private func run() {
        guard !reduceMotion else { return }
        scale = 0.6
        opacity = 0
        withAnimation(.easeOut(duration: 0.28)) {
            scale = 1.06
            opacity = 1
        }
        withAnimation(.easeInOut(duration: 0.12).delay(0.28)) {
            scale = 1
        }
    }

    public init(
        trigger: Trigger
    ) {
        self.trigger = trigger
    }
}

extension View {
    public func popIn<Trigger: Equatable>(trigger: Trigger) -> some View {
        modifier(PopIn(trigger: trigger))
    }
}
