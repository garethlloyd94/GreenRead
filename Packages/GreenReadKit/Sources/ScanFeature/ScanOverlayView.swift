import DesignSystem
import GreenReadCore
import SwiftUI

/// Draws the projected scan geometry over the camera: ball and hole markers, the lime
/// coverage paint, and on the result the curved 7pt lime line, dashed straight line and
/// aim ring. Strong sun (S5, Q15) makes the line and markers heavier.
struct ScanOverlayView: View {
    let overlay: ScanOverlay
    let step: ScanFlow.Step
    let highContrast: Bool
    let aimLabel: String?

    var body: some View {
        Canvas { context, _ in
            for quad in overlay.paint {
                context.fill(quadPath(quad), with: .color(GRColor.lime.opacity(highContrast ? 0.6 : 0.38)))
            }
            if step == .result {
                drawResult(&context)
            }
            if let hole = overlay.hole {
                drawHole(&context, at: hole)
            }
            if let ball = overlay.ball {
                drawBall(&context, at: ball)
            }
        }
        .overlay {
            GeometryReader { _ in
                if step == .mark {
                    if let ball = overlay.ball { pin("BALL", fill: .white).position(x: ball.x, y: ball.y - 34) }
                    if let hole = overlay.hole { pin("HOLE", fill: GRColor.lime).position(x: hole.x, y: hole.y - 30) }
                }
                if step == .result, let aim = overlay.aimPoint, let aimLabel {
                    Text(aimLabel)
                        .font(GRFont.archivo(12, weight: 800))
                        .foregroundStyle(GRColor.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.white))
                        .position(x: aim.x, y: aim.y - 30)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var scale: CGFloat { highContrast ? 1.4 : 1 }

    private func drawResult(_ context: inout GraphicsContext) {
        if let ball = overlay.ball, let aim = overlay.aimPoint {
            var straight = Path()
            straight.move(to: ball)
            straight.addLine(to: aim)
            context.stroke(straight, with: .color(.white), style: StrokeStyle(lineWidth: 3 * scale, dash: [9, 8]))
            let ring = Path(ellipseIn: CGRect(x: aim.x - 11 * scale, y: aim.y - 11 * scale, width: 22 * scale, height: 22 * scale))
            context.stroke(ring, with: .color(.white), lineWidth: 3.5 * scale)
        }
        if overlay.line.count > 1 {
            var curve = Path()
            curve.addLines(overlay.line)
            context.stroke(
                curve,
                with: .color(GRColor.lime),
                style: StrokeStyle(lineWidth: (highContrast ? 10 : 7), lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawBall(_ context: inout GraphicsContext, at point: CGPoint) {
        let radius = (step == .result ? 11 : 10) * scale
        context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(.white))
    }

    private func drawHole(_ context: inout GraphicsContext, at point: CGPoint) {
        let size = CGSize(width: 32 * scale, height: 14 * scale)
        let rect = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
        context.fill(Path(ellipseIn: rect), with: .color(GRColor.ink))
        context.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 2)
    }

    private func pin(_ label: String, fill: Color) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(GRFont.archivo(11, weight: 800))
                .foregroundStyle(GRColor.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 8).fill(fill))
            Rectangle().fill(fill).frame(width: 3, height: 24)
        }
    }

    private func quadPath(_ quad: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(quad)
        path.closeSubpath()
        return path
    }
}

extension ScanOverlay {
    /// Fixed screen positions matching the prototype, for the Simulator (no AR).
    func useLayoutPreview(for step: ScanFlow.Step, points: Int, coverage: Double, aim: AimResult?) {
        let screen = CGSize(width: 393, height: 852)
        let ballPoint = CGPoint(x: screen.width * 0.5, y: screen.height * 0.63)
        let holePoint = CGPoint(x: screen.width * 0.55, y: screen.height * 0.25)
        switch step {
        case .mark:
            ball = points > 0 ? ballPoint : nil
            hole = points > 1 ? holePoint : nil
            paint = []
            line = []
            aimPoint = nil
        case .scanning, .poorScan:
            ball = ballPoint
            hole = holePoint
            let width = screen.width * 0.6 * max(0.3, coverage)
            paint = [[
                CGPoint(x: screen.width / 2 - width / 2, y: holePoint.y - 20),
                CGPoint(x: screen.width / 2 + width / 2, y: holePoint.y - 20),
                CGPoint(x: screen.width / 2 + width / 2, y: ballPoint.y + 20),
                CGPoint(x: screen.width / 2 - width / 2, y: ballPoint.y + 20),
            ]]
            line = []
            aimPoint = nil
        case .result:
            ball = ballPoint
            hole = holePoint
            paint = []
            let aimMetres = aim.map(BreakLine.aimMetres) ?? 0
            let pixelsPerMetre = (ballPoint.y - holePoint.y) / 3
            let axis = CGPoint(x: holePoint.x - ballPoint.x, y: holePoint.y - ballPoint.y)
            line = BreakLine.points(length: 3, aimMetres: aimMetres).map { point in
                CGPoint(
                    x: ballPoint.x + axis.x * point.u / 3 + point.v * pixelsPerMetre,
                    y: ballPoint.y + axis.y * point.u / 3
                )
            }
            aimPoint = CGPoint(x: holePoint.x + aimMetres * pixelsPerMetre, y: holePoint.y)
        default:
            break
        }
    }
}
