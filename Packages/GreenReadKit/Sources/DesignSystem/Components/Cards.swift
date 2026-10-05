import GreenReadCore
import SwiftUI

/// White rounded card used throughout (radius 22–26, padding 16–20).
public struct GRCard<Content: View>: View {
    public var radius: CGFloat = GRMetrics.cardRadius
    public var padding: CGFloat = GRMetrics.cardPadding
    public var fill: Color = GRColor.card
    @ViewBuilder public let content: Content

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
    }

    public init(
        radius: CGFloat = GRMetrics.cardRadius,
        padding: CGFloat = GRMetrics.cardPadding,
        fill: Color = GRColor.card,
        @ViewBuilder content: () -> Content
    ) {
        self.radius = radius
        self.padding = padding
        self.fill = fill
        self.content = content()
    }
}

/// Card pinned to the bottom of a camera screen, top corners 30pt.
public struct BottomCard<Content: View>: View {
    @ViewBuilder public let content: Content

    public var body: some View {
        content
            .padding(.horizontal, GRMetrics.screenPadding)
            .padding(.top, 20)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: GRMetrics.sheetRadius,
                    topTrailingRadius: GRMetrics.sheetRadius,
                    style: .continuous
                )
                .fill(GRColor.card)
                .ignoresSafeArea(edges: .bottom)
            )
    }

    public init(
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
    }
}

/// Small uppercase mono label over a bold value: "ACTUAL / 15 ft".
public struct LabeledValue: View {
    public let label: String
    public let value: String
    public var valueColour: Color = GRColor.ink
    public var labelColour: Color = GRColor.textSecondary
    public var valueSize: CGFloat = 20

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).gr(.labelSmall).foregroundStyle(labelColour)
            Text(value)
                .grFont(.archivo(valueSize, weight: 800))
                .foregroundStyle(valueColour)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    public init(
        label: String,
        value: String,
        valueColour: Color = GRColor.ink,
        labelColour: Color = GRColor.textSecondary,
        valueSize: CGFloat = 20
    ) {
        self.label = label
        self.value = value
        self.valueColour = valueColour
        self.labelColour = labelColour
        self.valueSize = valueSize
    }
}

/// Big aim number: value in Archivo 800 expanded, unit smaller, then side. "16in R".
public struct AimNumber: View {
    public let aim: AimDisplay
    public var size: CGFloat = 56
    public var colour: Color = GRColor.green

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public var body: some View {
        composed
            .tracking(scaledSize * -0.02)
            .foregroundStyle(colour)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityLabel(aim.accessibilityText)
    }

    /// Value and side at full size, unit at 45%.
    private var composed: Text {
        let number = GRFont.archivo(scaledSize, weight: 800, width: 115)
        let unitFont = GRFont.archivo(scaledSize * 0.45, weight: 800, width: 110)
        let unitText = aim.unit == "in" ? "in" : " \(aim.unit)"
        let sideText = aim.side.isEmpty ? "" : " \(aim.side)"
        return Text(aim.value).font(number) + Text(unitText).font(unitFont) + Text(sideText).font(number)
    }

    private var scaledSize: CGFloat {
        GRFont.scaledSize(size, for: dynamicTypeSize)
    }

    public init(
        aim: AimDisplay,
        size: CGFloat = 56,
        colour: Color = GRColor.green
    ) {
        self.aim = aim
        self.size = size
        self.colour = colour
    }
}

/// Quick Read / Scan result card: AIM hero, break note, then ACTUAL · PLAYS · SLOPE.
public struct ResultCard: View {
    public let aim: AimDisplay
    /// "R → L", shown as "breaks / R → L" at the top right. Nil hides it.
    public var breakLabel: String?
    public let actual: String
    public let plays: String
    /// "▲" uphill, "▼" downhill, nil when flat.
    public var playsMarker: String?
    public let slope: String
    /// Changes when a new result arrives, so the number pops again.
    public var popTrigger: Int = 0

    public var body: some View {
        GRCard(radius: GRMetrics.largeCardRadius, padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AIM").gr(.label).foregroundStyle(GRColor.textSecondary)
                        AimNumber(aim: aim).popIn(trigger: popTrigger)
                    }
                    Spacer(minLength: 8)
                    if let breakLabel {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("breaks")
                            Text(breakLabel)
                        }
                        .grFont(.archivo(13, weight: 700))
                        .foregroundStyle(GRColor.textSecondary)
                    }
                }
                HStack(alignment: .top, spacing: 6) {
                    LabeledValue(label: "ACTUAL", value: actual)
                    LabeledValue(label: playsMarker.map { "PLAYS \($0)" } ?? "PLAYS", value: plays)
                    LabeledValue(label: "SLOPE", value: slope)
                }
            }
        }
    }

    public init(
        aim: AimDisplay,
        breakLabel: String? = nil,
        actual: String,
        plays: String,
        playsMarker: String? = nil,
        slope: String,
        popTrigger: Int = 0
    ) {
        self.aim = aim
        self.breakLabel = breakLabel
        self.actual = actual
        self.plays = plays
        self.playsMarker = playsMarker
        self.slope = slope
        self.popTrigger = popTrigger
    }
}

/// One line of the "How we got this" working.
public struct WorkingLine: Identifiable, Equatable {
    public let id = UUID()
    public let label: String
    public let value: String

    public init(
        label: String,
        value: String
    ) {
        self.label = label
        self.value = value
    }
}

/// Collapsible "How we got this" panel with the Tour Read working.
public struct HowWeGotThisPanel: View {
    public let lines: [WorkingLine]
    public let total: String
    @Binding public var isExpanded: Bool

    public var body: some View {
        GRCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(GRMotion.fade) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Text("How we got this").gr(.headline)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .foregroundStyle(GRColor.ink)
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

                if isExpanded {
                    VStack(spacing: 8) {
                        ForEach(lines) { line in
                            row(line.label, line.value, valueColour: GRColor.ink)
                        }
                        Rectangle().fill(GRColor.fill).frame(height: 1)
                        row("aim", total, valueColour: GRColor.green, bold: true)
                    }
                    .padding(.bottom, 14)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func row(_ label: String, _ value: String, valueColour: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(GRColor.textSecondary)
            Spacer()
            Text(value).foregroundStyle(valueColour).fontWeight(bold ? .semibold : nil)
        }
        .grTextStyle(.working)
    }

    public init(
        lines: [WorkingLine],
        total: String,
        isExpanded: Binding<Bool>
    ) {
        self.lines = lines
        self.total = total
        self._isExpanded = isExpanded
    }
}

/// Dark insight card on Stats: "INSIGHT · 12 ROUNDS" + headline sentence.
public struct InsightCard: View {
    public let eyebrow: String
    public let headline: String
    public var action: (title: String, handler: () -> Void)?

    public var body: some View {
        GRCard(radius: 24, fill: GRColor.ink) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow).gr(.label).foregroundStyle(GRColor.lime)
                Text(headline)
                    .grFont(.archivo(21, weight: 800))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                if let action {
                    Button(action: action.handler) {
                        Text("\(action.title) ›").gr(.headline).foregroundStyle(GRColor.lime)
                            .frame(minHeight: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    public init(
        eyebrow: String,
        headline: String,
        action: (title: String, handler: () -> Void)? = nil
    ) {
        self.eyebrow = eyebrow
        self.headline = headline
        self.action = action
    }
}

/// Light green note: "Your downhill reads are improving".
public struct PositiveNote: View {
    public let text: String

    public var body: some View {
        Text(text)
            .grFont(.archivo(14, weight: 700))
            .foregroundStyle(GRColor.greenTintText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(GRColor.greenTint))
    }

    public init(
        text: String
    ) {
        self.text = text
    }
}

extension AimDisplay {
    /// "16 inches right", "4 cups left".
    public var accessibilityText: String {
        let unitWord = unit == "in" ? (value == "1" ? "inch" : "inches") : unit
        let sideWord: String
        switch side {
        case "R": sideWord = " right"
        case "L": sideWord = " left"
        default: sideWord = ""
        }
        return "Aim \(value) \(unitWord)\(sideWord)"
    }
}

#Preview {
    struct Demo: View {
        @State var expanded = true
        var body: some View {
            ScrollView {
                VStack(spacing: 10) {
                    ResultCard(
                        aim: Format.aim(inches: 16, unit: .inches, side: .right),
                        breakLabel: "R → L",
                        actual: "15 ft",
                        plays: "17 ft",
                        playsMarker: "▲",
                        slope: "2.1%"
                    )
                    HowWeGotThisPanel(
                        lines: [
                            WorkingLine(label: "5 yd × 2 − 1", value: "9in @1%"),
                            WorkingLine(label: "× 2% slope", value: "18in"),
                            WorkingLine(label: "uphill adj.", value: "−2in")
                        ],
                        total: "16in R",
                        isExpanded: $expanded
                    )
                    InsightCard(eyebrow: "INSIGHT · 12 ROUNDS", headline: "You under-read left-to-right putts by about 30%")
                    PositiveNote(text: "Your downhill reads are improving")
                }
                .padding()
            }
            .background(GRColor.chalk)
        }
    }
    return Demo()
}
