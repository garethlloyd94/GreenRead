import SwiftUI

/// Full-width pill button, 56pt tall.
struct PillButton: View {
    enum Kind {
        /// Green: go, confirm, "Get started", "Lock in & lay phone".
        case go
        /// Ink: "Save", "Next · lay phone flat".
        case neutral
        /// Light fill: "New read", "Rescan".
        case secondary
        /// Lime on camera: "Start scan".
        case lime
    }

    let title: String
    var kind: Kind = .go
    var height: CGFloat = GRMetrics.primaryButtonHeight
    let action: () -> Void

    init(_ title: String, kind: Kind = .go, height: CGFloat = GRMetrics.primaryButtonHeight, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.height = height
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .gr(.button)
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
        .buttonStyle(PillButtonStyle(kind: kind))
    }
}

struct PillButtonStyle: ButtonStyle {
    let kind: PillButton.Kind
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(Capsule().fill(background(pressed: configuration.isPressed)))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(Capsule())
    }

    private var foreground: Color {
        switch kind {
        case .go, .neutral: .white
        case .secondary, .lime: GRColor.ink
        }
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .go: pressed ? GRColor.greenPressed : GRColor.green
        case .neutral: pressed ? GRColor.ink.opacity(0.85) : GRColor.ink
        case .secondary: pressed ? GRColor.border : GRColor.fillStrong
        case .lime: pressed ? GRColor.lime.opacity(0.85) : GRColor.lime
        }
    }
}

/// Round icon button: ✕ close (48pt white), ⚙ settings (46pt white), ↻ rescan.
struct CircleIconButton: View {
    enum Kind {
        case light, dark, green
    }

    let systemName: String
    let accessibilityLabel: String
    var size: CGFloat = GRMetrics.circleButton
    var kind: Kind = .light
    var floating = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(kind == .light ? GRColor.ink : Color.white)
                .frame(width: size, height: size)
                .background(Circle().fill(fill))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(minWidth: GRMetrics.minTapTarget, minHeight: GRMetrics.minTapTarget)
        .modifier(OptionalFloatingShadow(enabled: floating))
        .accessibilityLabel(accessibilityLabel)
    }

    private var fill: Color {
        switch kind {
        case .light: .white
        case .dark: GRColor.ink
        case .green: GRColor.green
        }
    }
}

/// Large round action, e.g. Tempo Start/Stop (96pt).
struct CircleActionButton: View {
    let title: String
    var size: CGFloat = 96
    var colour: Color = GRColor.green
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(GRFont.archivo(18, weight: 800))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(colour))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Green text button: "Enter manually", "Enter exact Stimp ›".
struct TextLinkButton: View {
    let title: String
    var colour: Color = GRColor.green
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .gr(.headline)
                .foregroundStyle(colour)
                .frame(minHeight: GRMetrics.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct OptionalFloatingShadow: ViewModifier {
    let enabled: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            content.floatingShadow()
        } else {
            content
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        PillButton("Primary · go") {}
        PillButton("Primary · neutral", kind: .neutral) {}
        PillButton("Secondary", kind: .secondary) {}
        PillButton("Start scan", kind: .lime) {}
        PillButton("Disabled", kind: .go) {}.disabled(true)
        HStack {
            CircleIconButton(systemName: "xmark", accessibilityLabel: "Close") {}
            CircleIconButton(systemName: "arrow.clockwise", accessibilityLabel: "Rescan", kind: .dark) {}
            CircleActionButton(title: "Start") {}
            TextLinkButton(title: "Text link") {}
        }
    }
    .padding()
    .background(GRColor.chalk)
}
