import GreenReadCore
import SwiftUI

/// White rounded card used throughout (radius 22–26, padding 16–20).
struct GRCard<Content: View>: View {
    var radius: CGFloat = GRMetrics.cardRadius
    var padding: CGFloat = GRMetrics.cardPadding
    var fill: Color = GRColor.card
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
    }
}

/// Card pinned to the bottom of a camera screen, top corners 30pt.
struct BottomCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
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
}

/// Small uppercase mono label over a bold value: "ACTUAL / 15 ft".
struct LabeledValue: View {
    let label: String
    let value: String
    var valueColour: Color = GRColor.ink
    var labelColour: Color = GRColor.textSecondary
    var valueSize: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).gr(.labelSmall).foregroundStyle(labelColour)
            Text(value)
                .font(GRFont.archivo(valueSize, weight: 800))
                .foregroundStyle(valueColour)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Big aim number: value in Archivo 800 expanded, unit smaller, then side. "16in R".
struct AimNumber: View {
    let aim: AimDisplay
    var size: CGFloat = 56
    var colour: Color = GRColor.green

    var body: some View {
        composed
            .tracking(size * -0.02)
            .foregroundStyle(colour)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityLabel(aim.accessibilityText)
    }

    /// Value and side at full size, unit at 45%.
    private var composed: Text {
        let number = GRFont.archivo(size, weight: 800, width: 115)
        let unitFont = GRFont.archivo(size * 0.45, weight: 800, width: 110)
        let unitText = aim.unit == "in" ? "in" : " \(aim.unit)"
        let sideText = aim.side.isEmpty ? "" : " \(aim.side)"
        return Text(aim.value).font(number) + Text(unitText).font(unitFont) + Text(sideText).font(number)
    }
}

/// Quick Read / Scan result card: AIM hero, break note, then ACTUAL · PLAYS · SLOPE.
struct ResultCard: View {
    let aim: AimDisplay
    /// "R → L", shown as "breaks / R → L" at the top right. Nil hides it.
    var breakLabel: String?
    let actual: String
    let plays: String
    /// "▲" uphill, "▼" downhill, nil when flat.
    var playsMarker: String?
    let slope: String
    /// Changes when a new result arrives, so the number pops again.
    var popTrigger: Int = 0

    var body: some View {
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
                        .font(GRFont.archivo(13, weight: 700))
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
}

/// One line of the "How we got this" working.
struct WorkingLine: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let value: String
}

/// Collapsible "How we got this" panel with the Tour Read working.
struct HowWeGotThisPanel: View {
    let lines: [WorkingLine]
    let total: String
    @Binding var isExpanded: Bool

    var body: some View {
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
                    .frame(height: 52)
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
}

/// Dark insight card on Stats: "INSIGHT · 12 ROUNDS" + headline sentence.
struct InsightCard: View {
    let eyebrow: String
    let headline: String
    var action: (title: String, handler: () -> Void)?

    var body: some View {
        GRCard(radius: 24, fill: GRColor.ink) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow).gr(.label).foregroundStyle(GRColor.lime)
                Text(headline)
                    .font(GRFont.archivo(21, weight: 800))
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
}

/// Light green note: "Your downhill reads are improving".
struct PositiveNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(GRFont.archivo(14, weight: 700))
            .foregroundStyle(GRColor.greenTintText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(GRColor.greenTint))
    }
}

extension AimDisplay {
    /// "16 inches right", "4 cups left".
    var accessibilityText: String {
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
