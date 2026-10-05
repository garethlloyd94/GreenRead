import SwiftUI

/// Pill segmented control.
/// - `.light`: Home "Play | Drills" (46pt, track #E3E6DE, selected white).
/// - `.onCamera`: Quick Read "Read | Train" over the camera (42pt, translucent ink track).
/// - `.settings`: compact control inside Settings rows ("ft | m", "Inches | Cups | Balls").
public struct PillSegmentedControl<Value: Hashable>: View {
    public enum Style {
        case light, onCamera, settings
    }

    public let options: [Value]
    @Binding public var selection: Value
    public var style: Style = .light
    public let title: (Value) -> String

    @Namespace private var thumb

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { selection = option }
                } label: {
                    Text(title(option))
                        .grFont(labelFont)
                        .foregroundStyle(isSelected ? GRColor.ink : unselectedText)
                        .lineLimit(1)
                        .frame(maxWidth: style == .settings ? nil : .infinity, maxHeight: .infinity)
                        .padding(.horizontal, style == .settings ? 12 : 0)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Color.white)
                                    .shadow(color: GRColor.ink.opacity(style == .settings ? 0.08 : 0), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "thumb", in: thumb)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .frame(height: height)
        // The track has a fixed height, so labels stop growing at the largest non-accessibility size.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .frame(maxWidth: style == .settings ? nil : .infinity)
        .background(Capsule().fill(track))
    }

    private var height: CGFloat {
        switch style {
        case .light: GRMetrics.segmentedHeight
        case .onCamera: 42
        case .settings: 36
        }
    }

    private var labelFont: GRFontSpec {
        switch style {
        case .light: .archivo(15, weight: 800)
        case .onCamera: .archivo(14, weight: 800)
        case .settings: .archivo(13, weight: 700)
        }
    }

    private var track: Color {
        switch style {
        case .light: GRColor.fillStrong
        case .onCamera: GRColor.ink.opacity(0.6)
        case .settings: GRColor.fill
        }
    }

    private var unselectedText: Color {
        switch style {
        case .light, .settings: GRColor.textSecondary
        case .onCamera: GRColor.textOnDarkMuted
        }
    }

    public init(
        options: [Value],
        selection: Binding<Value>,
        style: Style = .light,
        title: @escaping (Value) -> String
    ) {
        self.options = options
        self._selection = selection
        self.style = style
        self.title = title
    }
}

#Preview {
    struct Demo: View {
        @State var tab = "Play"
        @State var mode = "Read"
        @State var unit = "Inches"
        var body: some View {
            VStack(spacing: 24) {
                PillSegmentedControl(options: ["Play", "Drills"], selection: $tab) { $0 }
                PillSegmentedControl(options: ["Read", "Train"], selection: $mode, style: .onCamera) { $0 }
                    .frame(width: 220)
                    .padding()
                    .background(GRColor.turfDark)
                PillSegmentedControl(options: ["Inches", "Cups", "Balls"], selection: $unit, style: .settings) { $0 }
            }
            .padding()
            .background(GRColor.chalk)
        }
    }
    return Demo()
}
