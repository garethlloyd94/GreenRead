import GreenReadCore
import SwiftUI

extension Verdict {
    /// Spot on = green, Under-read and Wrong way = clay, Over-read = slate.
    public var colour: Color {
        switch self {
        case .spotOn: GRColor.green
        case .underRead, .wrongWay: GRColor.clay
        case .overRead: GRColor.slate
        }
    }
}

/// Full-width verdict banner on the Train reveal: "Under-read / You read 2%, it was 3%".
public struct VerdictBanner: View {
    public let verdict: Verdict
    public let detail: String

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verdict.title)
                .font(GRFont.archivo(34, weight: 800, width: 110))
                .tracking(34 * -0.02)
            Text(detail)
                .font(GRFont.archivo(15, weight: 600))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(verdict.colour))
        .popIn(trigger: verdict)
        .accessibilityElement(children: .combine)
    }

    public init(
        verdict: Verdict,
        detail: String
    ) {
        self.verdict = verdict
        self.detail = detail
    }
}

/// Small coloured verdict pill: "Spot on", "Under-read", "Over-read".
public struct VerdictPill: View {
    public let verdict: Verdict

    public var body: some View {
        Text(verdict.title)
            .font(GRFont.archivo(14, weight: 800))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule().fill(verdict.colour))
    }

    public init(
        verdict: Verdict
    ) {
        self.verdict = verdict
    }
}

/// One column of the guess / reveal comparison.
/// "YOU" is white with ink text; "ACTUAL" is ink with mismatched values in light clay.
public struct RevealColumn: View {
    public struct Row: Identifiable {
        public let id = UUID()
        public let text: String
        /// True when this row differs from the golfer's read.
        public var mismatch: Bool = false

        public init(
            text: String,
            mismatch: Bool = false
        ) {
            self.text = text
            self.mismatch = mismatch
        }
    }

    public let title: String
    public let headline: String
    /// True when the slope differs from the golfer's read.
    public var headlineMismatch: Bool = false
    public let rows: [Row]
    public var isActual: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).gr(.labelSmall).foregroundStyle(isActual ? GRColor.textOnDarkMuted : GRColor.textSecondary)
            Text(headline)
                .font(GRFont.archivo(22, weight: 800))
                .foregroundStyle(isActual && headlineMismatch ? GRColor.clayOnDark : textColour)
            ForEach(rows) { row in
                Text(row.text)
                    .font(GRFont.archivo(15, weight: 700))
                    .foregroundStyle(isActual && row.mismatch ? GRColor.clayOnDark : textColour)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(isActual ? GRColor.ink : GRColor.card))
        .accessibilityElement(children: .combine)
    }

    private var textColour: Color { isActual ? .white : GRColor.ink }

    public init(
        title: String,
        headline: String,
        headlineMismatch: Bool = false,
        rows: [Row],
        isActual: Bool = false
    ) {
        self.title = title
        self.headline = headline
        self.headlineMismatch = headlineMismatch
        self.rows = rows
        self.isActual = isActual
    }
}

#Preview {
    VStack(spacing: 12) {
        VerdictBanner(verdict: .underRead, detail: "You read 2%, it was 3%")
        HStack(spacing: 10) {
            RevealColumn(title: "YOU", headline: "2%", rows: [.init(text: "R → L"), .init(text: "12in R")])
            RevealColumn(
                title: "ACTUAL",
                headline: "3.1%",
                headlineMismatch: true,
                rows: [.init(text: "R → L ✓"), .init(text: "25in R", mismatch: true)],
                isActual: true
            )
        }
        HStack {
            ForEach(Verdict.allCases.filter { $0 != .wrongWay }, id: \.self) { VerdictPill(verdict: $0) }
        }
    }
    .padding()
    .background(GRColor.chalk)
}
