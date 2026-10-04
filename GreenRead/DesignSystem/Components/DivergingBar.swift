import SwiftUI

/// Stats breakdown row: label, then a bar growing left (under-read, clay) or
/// right (over-read, slate) from a centre line.
struct DivergingBar: View {
    let label: String
    /// Signed error as a fraction: −0.3 = under-read by 30%, +0.1 = over-read by 10%.
    /// As in the prototype, the bar is that fraction of the full track width (capped at half).
    let value: Double

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(GRFont.archivo(13, weight: 600))
                .foregroundStyle(GRColor.ink)
                .frame(width: 70, alignment: .leading)
            GeometryReader { proxy in
                let half = proxy.size.width / 2
                let clamped = min(max(value, -0.5), 0.5)
                let width = proxy.size.width * CGFloat(abs(clamped))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(clamped < 0 ? GRColor.clay : GRColor.slate)
                        .frame(width: width, height: 14)
                        .offset(x: clamped < 0 ? half - width : half)
                    Rectangle()
                        .fill(GRColor.ink)
                        .frame(width: 1.5, height: 20)
                        .offset(x: half - 0.75)
                }
                .frame(height: proxy.size.height)
            }
            .frame(height: 20)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let percent = Int((abs(value) * 100).rounded())
        if percent == 0 { return "On target" }
        return value < 0 ? "Under-read by \(percent)%" : "Over-read by \(percent)%"
    }
}

/// "◀ UNDER  ·  OVER ▶" header above a stack of diverging bars.
struct DivergingBarLegend: View {
    var body: some View {
        HStack {
            Text("◀ UNDER")
            Spacer()
            Text("OVER ▶")
        }
        .grTextStyle(.labelSmall)
        .foregroundStyle(GRColor.textSecondary)
        .padding(.leading, 78)
    }
}

#Preview {
    VStack(spacing: 10) {
        DivergingBarLegend()
        DivergingBar(label: "L → R", value: -0.34)
        DivergingBar(label: "R → L", value: -0.08)
        DivergingBar(label: "Uphill", value: 0.14)
        DivergingBar(label: "Downhill", value: -0.22)
        DivergingBar(label: "3–4%", value: -0.28)
        DivergingBar(label: "20 ft+", value: 0.10)
    }
    .padding()
    .background(.white)
}
