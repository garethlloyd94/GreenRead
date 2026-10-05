import SwiftUI

/// Striped placeholder used where a camera feed or thumbnail will go.
public struct StripedPlaceholder: View {
    public var dark: Color = GRColor.thumbDark
    public var light: Color = GRColor.thumbLight
    public var stripe: CGFloat = 8

    public var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(light))
            let span = size.width + size.height
            var x: CGFloat = -size.height
            while x < span {
                var band = Path()
                band.move(to: CGPoint(x: x, y: size.height))
                band.addLine(to: CGPoint(x: x + stripe, y: size.height))
                band.addLine(to: CGPoint(x: x + stripe + size.height, y: 0))
                band.addLine(to: CGPoint(x: x + size.height, y: 0))
                band.closeSubpath()
                context.fill(band, with: .color(dark))
                x += stripe * 2
            }
        }
        .accessibilityHidden(true)
    }

    public init(
        dark: Color = GRColor.thumbDark,
        light: Color = GRColor.thumbLight,
        stripe: CGFloat = 8
    ) {
        self.dark = dark
        self.light = light
        self.stripe = stripe
    }
}

/// Drills feed row: thumbnail with duration badge, title, "creator · category", ♥ save.
public struct VideoRow: View {
    public let title: String
    public let subtitle: String
    public let duration: String
    public let isSaved: Bool
    public let onOpen: () -> Void
    public let onToggleSave: () -> Void

    public var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    StripedPlaceholder()
                        .frame(width: 120, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            Text(duration)
                                .grFont(.archivo(11, weight: 700))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(RoundedRectangle(cornerRadius: 6).fill(GRColor.ink))
                                .padding(6)
                        }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .grFont(.archivo(15, weight: 700))
                            .foregroundStyle(GRColor.ink)
                            .multilineTextAlignment(.leading)
                        Text(subtitle)
                            .grFont(.archivo(12, weight: 500))
                            .foregroundStyle(GRColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(subtitle), \(duration)")

            Button(action: onToggleSave) {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSaved ? GRColor.green : GRColor.textMuted)
                    .frame(width: GRMetrics.minTapTarget, height: GRMetrics.minTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSaved ? "Remove from saved" : "Save")
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: GRMetrics.cardRadius, style: .continuous).fill(GRColor.card))
    }

    public init(
        title: String,
        subtitle: String,
        duration: String,
        isSaved: Bool,
        onOpen: @escaping () -> Void,
        onToggleSave: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
        self.isSaved = isSaved
        self.onOpen = onOpen
        self.onToggleSave = onToggleSave
    }
}

/// Green on/off switch from Settings (46 × 28).
public struct GRToggleStyle: ToggleStyle {
    public func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { configuration.isOn.toggle() }
        } label: {
            HStack {
                configuration.label
                Spacer()
                Capsule()
                    .fill(configuration.isOn ? GRColor.green : GRColor.textOnDarkMuted)
                    .frame(width: 46, height: 28)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(.white).frame(width: 22, height: 22).padding(3)
                    }
            }
            .frame(minHeight: GRMetrics.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

#Preview {
    struct Demo: View {
        @State var saved = true
        @State var haptics = true
        var body: some View {
            VStack(spacing: 12) {
                VideoRow(
                    title: "The gate drill for 6-footers",
                    subtitle: "Coach Name · Short putts",
                    duration: "4:12",
                    isSaved: saved,
                    onOpen: {},
                    onToggleSave: { saved.toggle() }
                )
                Toggle("Haptics", isOn: $haptics)
                    .toggleStyle(GRToggleStyle())
                    .grFont(.archivo(15, weight: 600))
            }
            .padding()
            .background(GRColor.chalk)
        }
    }
    return Demo()
}
