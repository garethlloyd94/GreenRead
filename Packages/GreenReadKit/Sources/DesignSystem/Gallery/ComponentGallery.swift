#if DEBUG
import GreenReadCore
import SwiftUI

/// Debug-only sheet of every design-system component, for comparing against the
/// design pack's component board. Not shipped in release builds.
public struct ComponentGallery: View {
    public init() {}

    @State private var tab = "Play"
    @State private var mode = "Read"
    @State private var aimUnit: AimUnit = .inches
    @State private var category = "All"
    @State private var slope: Int? = 2
    @State private var direction: BreakDirection? = .rightToLeft
    @State private var hill: Hill? = .up
    @State private var howOpen = false
    @State private var saved = true
    @State private var haptics = true
    @State private var sounds = true
    @State private var pop = 0

    private let categories = ["All", "Saved", "Green reading", "Speed control", "Tempo", "Alignment", "Short putts"]

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                section("BRAND") {
                    Wordmark()
                    Wordmark(onDark: true)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 20).fill(GRColor.ink))
                    paletteRow
                }

                section("BUTTONS") {
                    PillButton("Primary · go") {}
                    PillButton("Primary · neutral", kind: .neutral) {}
                    PillButton("Secondary", kind: .secondary) {}
                    PillButton("Start scan", kind: .lime) {}
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 20).fill(GRColor.turfDark))
                    PillButton("Disabled until both are placed", kind: .go) {}
                        .disabled(true)
                    HStack(spacing: 14) {
                        CircleIconButton(systemName: "arrow.clockwise", accessibilityLabel: "Rescan") {}
                        CircleIconButton(systemName: "xmark", accessibilityLabel: "Close", kind: .dark) {}
                        CircleActionButton(title: "Save", size: 84) {}
                        TextLinkButton(title: "Text link") {}
                    }
                }

                section("CHIPS & SEGMENTED") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { c in
                                Chip(title: c, isSelected: category == c) { category = c }
                            }
                        }
                    }
                    ChipGroup(label: "SLOPE", options: [1, 2, 3, 4], selection: $slope) { "\($0)%" }
                    ChipGroup(label: "BREAK", options: BreakDirection.allCases, selection: $direction) { $0.label }
                    ChipGroup(label: "HILL", options: Hill.allCases, selection: $hill) { $0.label }
                    HStack(spacing: 10) {
                        PillSegmentedControl(options: ["Play", "Drills"], selection: $tab) { $0 }
                        CircleIconButton(systemName: "gearshape.fill", accessibilityLabel: "Settings", size: 46) {}
                    }
                    PillSegmentedControl(options: ["Read", "Train"], selection: $mode, style: .onCamera) { $0 }
                        .frame(width: 220)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 20).fill(GRColor.turfDark))
                    HStack {
                        Text("Aim unit").gr(.body)
                        Spacer()
                        PillSegmentedControl(options: AimUnit.allCases, selection: $aimUnit, style: .settings) { $0.title }
                    }
                }

                section("RESULT CARD · AIM UNIT FOLLOWS SETTINGS") {
                    let result = TourRead.read(feet: 15, slope: SlopeReading(uphillPercent: 1.2, sidePercent: 2.1))
                    ResultCard(
                        aim: Format.aim(inches: result.aimInches, unit: aimUnit, side: result.aimSide),
                        breakLabel: "R → L",
                        actual: Format.distance(feet: 15, unit: .feet),
                        plays: Format.distance(feet: result.playsLikeFeet, unit: .feet),
                        playsMarker: "▲",
                        slope: Format.slope(percent: 2.1),
                        popTrigger: pop
                    )
                    HowWeGotThisPanel(
                        lines: [
                            WorkingLine(label: "\(Format.yards(feet: 15)) × 2 − 1", value: "\(Format.aim(inches: result.breakdown.onePercentInches, unit: aimUnit).amount) @1%"),
                            WorkingLine(label: "× \(result.breakdown.slopePercent)% slope", value: Format.aim(inches: result.breakdown.scaledInches, unit: aimUnit).amount),
                            WorkingLine(label: "uphill adj.", value: Format.signedAim(inches: result.breakdown.hillAdjustmentInches, unit: aimUnit))
                        ],
                        total: Format.aim(inches: result.aimInches, unit: aimUnit, side: result.aimSide).text,
                        isExpanded: $howOpen
                    )
                    PillButton("Replay pop animation", kind: .secondary) { pop += 1 }
                }

                section("GUESS / REVEAL") {
                    VerdictBanner(verdict: .underRead, detail: "You read 2%, it was 3%")
                    HStack(spacing: 10) {
                        RevealColumn(title: "YOU", headline: "2%", rows: [.init(text: "R → L"), .init(text: "▲ Up"), .init(text: "12in R")])
                        RevealColumn(
                            title: "ACTUAL",
                            headline: "3.1%",
                            headlineMismatch: true,
                            rows: [.init(text: "R → L ✓"), .init(text: "▲ Up ✓"), .init(text: "25in R", mismatch: true)],
                            isActual: true
                        )
                    }
                    HStack(spacing: 8) {
                        VerdictPill(verdict: .spotOn)
                        VerdictPill(verdict: .underRead)
                        VerdictPill(verdict: .overRead)
                    }
                }

                section("INSIGHT & BREAKDOWN") {
                    InsightCard(eyebrow: "INSIGHT · 12 ROUNDS", headline: "You under-read left-to-right putts by about 30%")
                    PositiveNote(text: "Your downhill reads are improving")
                    GRCard {
                        VStack(spacing: 10) {
                            DivergingBarLegend()
                            DivergingBar(label: "L → R", value: -0.34)
                            DivergingBar(label: "R → L", value: -0.08)
                            DivergingBar(label: "Uphill", value: 0.14)
                            DivergingBar(label: "Downhill", value: -0.22)
                            DivergingBar(label: "3–4%", value: -0.28)
                            DivergingBar(label: "20 ft+", value: 0.10)
                        }
                    }
                }

                section("VIDEO ROW") {
                    VideoRow(
                        title: "The gate drill for 6-footers",
                        subtitle: "Coach Name · Short putts",
                        duration: "4:12",
                        isSaved: saved,
                        onOpen: {},
                        onToggleSave: { saved.toggle() }
                    )
                }

                section("SETTINGS CONTROLS") {
                    GRCard(padding: 0) {
                        VStack(spacing: 0) {
                            Toggle("Sounds", isOn: $sounds).toggleStyle(GRToggleStyle())
                            Rectangle().fill(GRColor.fill).frame(height: 1)
                            Toggle("Haptics", isOn: $haptics).toggleStyle(GRToggleStyle())
                        }
                        .font(GRFont.archivo(15, weight: 600))
                        .foregroundStyle(GRColor.ink)
                        .padding(.horizontal, 16)
                    }
                    Text("Practice & casual play only. Slope-reading devices aren't allowed during competitive rounds under the Rules of Golf.")
                        .font(GRFont.archivo(13, weight: 600))
                        .foregroundStyle(GRColor.clayTintText)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(GRColor.clayTint))
                }

                section("BOTTOM CARD ON CAMERA") {
                    ZStack(alignment: .bottom) {
                        StripedPlaceholder(dark: GRColor.turfDark, light: GRColor.turfLight, stripe: 10)
                        BottomCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("STEP 1 · DISTANCE").gr(.labelSmall).foregroundStyle(GRColor.textSecondary)
                                Text("15 ft").font(GRFont.archivo(34, weight: 800, width: 110))
                                PillButton("Next · lay phone flat", kind: .neutral) {}
                            }
                        }
                    }
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            }
            .padding(.horizontal, GRMetrics.screenPadding)
            .padding(.vertical, 20)
        }
        .background(GRColor.chalk)
        .navigationTitle("Components")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var paletteRow: some View {
        let swatches: [(String, Color)] = [
            ("Ink", GRColor.ink), ("Chalk", GRColor.chalk), ("Green", GRColor.green), ("Lime", GRColor.lime),
            ("Clay", GRColor.clay), ("Slate", GRColor.slate), ("Moss", GRColor.textSecondary)
        ]
        return HStack(spacing: 6) {
            ForEach(swatches, id: \.0) { swatch in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(swatch.1)
                        .frame(height: 36)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(GRColor.border, lineWidth: 0.5))
                    Text(swatch.0.uppercased()).gr(.labelSmall).foregroundStyle(GRColor.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).gr(.label).foregroundStyle(GRColor.textSecondary)
            content()
        }
    }
}

#Preview {
    NavigationStack { ComponentGallery() }
}
#endif
