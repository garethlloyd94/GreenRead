import SwiftUI

/// Selectable chip. Selected = ink fill, white text; unselected = white fill.
struct Chip: View {
    enum Style {
        /// Category filter: compact capsule ("Green reading").
        case pill
        /// Guess form: 52pt tall, radius 14, bold ("2%", "R→L").
        case block
    }

    let title: String
    let isSelected: Bool
    var style: Style = .pill
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            chipLabel
                .foregroundStyle(isSelected ? Color.white : GRColor.ink)
                .background(chipBackground)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var chipLabel: some View {
        switch style {
        case .pill:
            Text(title)
                .gr(.chip)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
        case .block:
            Text(title)
                .font(GRFont.archivo(17, weight: 800))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: GRMetrics.chipHeight)
        }
    }

    @ViewBuilder private var chipBackground: some View {
        switch style {
        case .pill:
            Capsule().fill(isSelected ? GRColor.ink : Color.white)
        case .block:
            RoundedRectangle(cornerRadius: GRMetrics.chipRadius, style: .continuous)
                .fill(isSelected ? GRColor.ink : Color.white)
        }
    }
}

/// A row of block chips for one guess question, e.g. SLOPE 1% 2% 3% 4%.
struct ChipGroup<Value: Hashable>: View {
    let label: String
    let options: [Value]
    @Binding var selection: Value?
    let title: (Value) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).gr(.label).foregroundStyle(GRColor.textSecondary)
            HStack(spacing: 7) {
                ForEach(options, id: \.self) { option in
                    Chip(title: title(option), isSelected: selection == option, style: .block) {
                        selection = option
                    }
                }
            }
        }
    }
}

#Preview {
    struct Demo: View {
        @State var category = "Green reading"
        @State var slope: Int? = 2
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["All", "Saved", "Green reading", "Speed control", "Tempo"], id: \.self) { c in
                            Chip(title: c, isSelected: category == c) { category = c }
                        }
                    }
                }
                ChipGroup(label: "SLOPE", options: [1, 2, 3, 4], selection: $slope) { "\($0)%" }
            }
            .padding()
            .background(GRColor.chalk)
        }
    }
    return Demo()
}
