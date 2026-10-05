import SwiftUI

/// "GreenRead" set in Archivo 800, width 118%, tracking −0.03em, with the
/// "FIND THE LINE" tagline. Always text, never an image.
public struct Wordmark: View {
    public var size: CGFloat = 30
    public var onDark: Bool = false
    public var showsTagline: Bool = true

    public var body: some View {
        VStack(alignment: .leading, spacing: size * 0.08) {
            (Text("Green").foregroundStyle(onDark ? Color.white : GRColor.ink)
                + Text("Read").foregroundStyle(onDark ? GRColor.lime : GRColor.green))
                .font(GRFont.archivo(size, weight: 800, width: 118))
                .tracking(size * -0.03)
            if showsTagline {
                Text("FIND THE LINE")
                    .font(GRFont.mono(max(10, size * 0.37), weight: 600))
                    .tracking(max(10, size * 0.37) * 0.1)
                    .foregroundStyle(onDark ? GRColor.textOnDarkMuted : GRColor.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("GreenRead. Find the line.")
    }

    public init(
        size: CGFloat = 30,
        onDark: Bool = false,
        showsTagline: Bool = true
    ) {
        self.size = size
        self.onDark = onDark
        self.showsTagline = showsTagline
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        Wordmark()
        Wordmark(size: 22)
        Wordmark(onDark: true)
            .padding()
            .background(GRColor.ink)
    }
    .padding()
}
