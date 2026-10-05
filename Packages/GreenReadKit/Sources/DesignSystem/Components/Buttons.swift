import SwiftUI

/// Full-width pill button, 56pt tall.
public struct PillButton: View {
    public enum Kind {
        /// Green: go, confirm, "Get started", "Lock in & lay phone".
        case go
        /// Ink: "Save", "Next · lay phone flat".
        case neutral
        /// Light fill: "New read", "Rescan".
        case secondary
        /// Lime on camera: "Start scan".
        case lime
    }

    public let title: String
    public var kind: Kind = .go
    public var height: CGFloat = GRMetrics.primaryButtonHeight
    public let action: () -> Void

    public init(_ title: String, kind: Kind = .go, height: CGFloat = GRMetrics.primaryButtonHeight, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.height = height
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .gr(.button)
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
        .buttonStyle(PillButtonStyle(kind: kind))
    }
}

public struct PillButtonStyle: ButtonStyle {
    public let kind: PillButton.Kind
    @Environment(\.isEnabled) private var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
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

    public init(
        kind: PillButton.Kind
    ) {
        self.kind = kind
    }
}

/// Round icon button: ✕ close (48pt white), ⚙ settings (46pt white), ↻ rescan.
public struct CircleIconButton: View {
    public enum Kind {
        case light, dark, green
    }

    public let systemName: String
    public let accessibilityLabel: String
    public var size: CGFloat = GRMetrics.circleButton
    public var kind: Kind = .light
    public var floating: Bool = false
    public let action: () -> Void

    public var body: some View {
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

    public init(
        systemName: String,
        accessibilityLabel: String,
        size: CGFloat = GRMetrics.circleButton,
        kind: Kind = .light,
        floating: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.size = size
        self.kind = kind
        self.floating = floating
        self.action = action
    }
}

/// Large round action, e.g. Tempo Start/Stop (96pt).
public struct CircleActionButton: View {
    public let title: String
    public var size: CGFloat = 96
    public var colour: Color = GRColor.green
    public let action: () -> Void

    public var body: some View {
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

    public init(
        title: String,
        size: CGFloat = 96,
        colour: Color = GRColor.green,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.size = size
        self.colour = colour
        self.action = action
    }
}

/// Green text button: "Enter manually", "Enter exact Stimp ›".
public struct TextLinkButton: View {
    public let title: String
    public var colour: Color = GRColor.green
    public let action: () -> Void

    public var body: some View {
        Button(action: action) {
            Text(title)
                .gr(.headline)
                .foregroundStyle(colour)
                .frame(minHeight: GRMetrics.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    public init(
        title: String,
        colour: Color = GRColor.green,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.colour = colour
        self.action = action
    }
}

private struct OptionalFloatingShadow: ViewModifier {
    public let enabled: Bool
    @ViewBuilder public func body(content: Content) -> some View {
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
