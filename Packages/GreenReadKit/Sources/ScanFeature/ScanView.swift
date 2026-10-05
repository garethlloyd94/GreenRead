import ComposableArchitecture
import DesignSystem
import GreenReadCore
import SwiftUI

public struct ScanView: View {
    @Bindable var store: StoreOf<ScanFlow>
    @State private var overlay = ScanOverlay()
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<ScanFlow>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.step {
            case .checking:
                GRColor.ink.ignoresSafeArea()
            case .noLiDAR:
                NoLiDARView { store.send(.useQuickReadButtonTapped) }
            case let .cameraPrimer(isDenied):
                CameraPrimerView(
                    isDenied: isDenied,
                    allow: { store.send(.allowCameraButtonTapped) },
                    openSettings: { store.send(.openSettingsButtonTapped) },
                    useQuickRead: { store.send(.useQuickReadButtonTapped) }
                )
            case .mark, .scanning, .poorScan, .result:
                camera
            }
        }
        .task { await store.send(.task).finish() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.send(.appBecameActive) }
        }
        .sheet(item: $store.scope(state: \.greenSpeed, action: \.greenSpeed)) { pickerStore in
            GreenSpeedSheet(store: pickerStore)
        }
    }

    private var camera: some View {
        ZStack {
            cameraLayer
                .ignoresSafeArea()
            ScanOverlayView(
                overlay: overlay,
                step: store.step,
                highContrast: store.isBrightSun,
                aimLabel: aimLabel
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            stepControls
        }
    }

    @ViewBuilder private var cameraLayer: some View {
        if isARRunnable {
            ScanARView(
                configuration: ScanARConfiguration(
                    stage: arStage,
                    ball: store.ball,
                    hole: store.hole,
                    scanID: store.scanID,
                    aimMetres: store.result.map(BreakLine.aimMetres)
                ),
                overlay: overlay,
                onTap: { store.send(.arPointPlaced($0)) },
                onProgress: { store.send(.scanProgressed($0)) },
                onBrightSun: { store.send(.lightChanged(isBright: $0)) }
            )
        } else {
            StripedPlaceholder(dark: GRColor.turfDark, light: GRColor.turfLight, stripe: 12)
                .onAppear { overlay.useLayoutPreview(for: store.step, points: store.points.count, coverage: store.progress.coverage, aim: store.result) }
                .onChange(of: store.step) { _, step in
                    overlay.useLayoutPreview(for: step, points: store.points.count, coverage: store.progress.coverage, aim: store.result)
                }
                .onChange(of: store.points.count) { _, count in
                    overlay.useLayoutPreview(for: store.step, points: count, coverage: store.progress.coverage, aim: store.result)
                }
        }
    }

    private var isARRunnable: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    private var arStage: ScanARConfiguration.Stage {
        switch store.step {
        case .scanning: .scanning
        case .poorScan: .paused
        case .result: .result
        default: .mark
        }
    }

    private var aimLabel: String? {
        guard let result = store.result else { return nil }
        return "AIM \(store.settings.aim(inches: result.aimInches, side: result.aimSide).text)"
    }

    @ViewBuilder private var stepControls: some View {
        VStack(spacing: 0) {
            if store.isBrightSun {
                BrightSunBanner()
                    .padding(.top, 64)
                    .padding(.horizontal, GRMetrics.screenPadding)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            switch store.step {
            case .mark:
                MarkControls(store: store)
            case .scanning:
                ScanningControls(store: store)
            case .poorScan:
                PoorScanCard(store: store)
            case .result:
                ScanResultCard(store: store)
            default:
                EmptyView()
            }
        }
        .animation(GRMotion.fade, value: store.isBrightSun)
    }
}

// MARK: - Mark (S1)

private struct MarkControls: View {
    let store: StoreOf<ScanFlow>

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                if store.ball != nil {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(GRColor.green)
                    Text("Ball ·").foregroundStyle(GRColor.ink)
                }
                Text(prompt).foregroundStyle(store.ball != nil && store.hole == nil ? GRColor.green : GRColor.ink)
            }
            .font(GRFont.archivo(17, weight: 800))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Capsule().fill(.white))
            .padding(.top, 116)
            Spacer()
            HStack(spacing: 10) {
                Button { store.send(.undoButtonTapped) } label: {
                    Text("Undo").gr(.button).foregroundStyle(.white)
                        .frame(width: 112, height: 58)
                        .background(Capsule().fill(GRColor.ink.opacity(0.7)))
                }
                .buttonStyle(.plain)
                .disabled(store.points.isEmpty)
                .opacity(store.points.isEmpty ? 0.5 : 1)
                Group {
                    if store.hole != nil {
                        PillButton("Start scan", kind: .lime, height: 58) { store.send(.startScanButtonTapped) }
                    } else {
                        Text("Mark ball & hole")
                            .gr(.button)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 58)
                            .background(Capsule().fill(.white.opacity(0.25)))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, GRMetrics.screenPadding)
            .padding(.bottom, 16)
        }
    }

    private var prompt: String {
        switch store.points.count {
        case 0: "Tap the ball"
        case 1: "Now tap the hole"
        default: "Ball & hole set"
        }
    }
}

// MARK: - Scanning (2a)

private struct ScanningControls: View {
    let store: StoreOf<ScanFlow>

    var body: some View {
        VStack {
            HStack {
                Spacer()
                ProgressRing(fraction: store.progress.coverage)
            }
            .padding(.top, 116)
            .padding(.horizontal, GRMetrics.screenPadding)
            Spacer()
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Circle().fill(GRColor.clay).frame(width: 11, height: 11)
                    Text(store.progress.prompt.text)
                }
                .font(GRFont.archivo(22, weight: 800))
                .foregroundStyle(GRColor.ink)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Capsule().fill(.white))
                .animation(GRMotion.fade, value: store.progress.prompt)
                .accessibilityAddTraits(.updatesFrequently)
                Text("Keep the green in frame")
                    .font(GRFont.archivo(13, weight: 600))
                    .foregroundStyle(.white)
                if store.progress.coverage >= 0.4 {
                    TextLinkButton(title: "Finish scan", colour: .white) {
                        store.send(.finishScanButtonTapped)
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }
}

/// 78pt ring with a lime sweep and the percentage in the middle.
private struct ProgressRing: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.25))
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(GRColor.lime, style: StrokeStyle(lineWidth: 8))
                .rotationEffect(.degrees(-90))
                .padding(4)
            Circle().fill(GRColor.ink).frame(width: 62, height: 62)
            Text("\(Int((fraction * 100).rounded()))%")
                .font(GRFont.archivo(18, weight: 800))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(width: 78, height: 78)
        .animation(.linear(duration: 0.2), value: fraction)
        .accessibilityElement()
        .accessibilityLabel("Scanned \(Int((fraction * 100).rounded())) percent")
    }
}

// MARK: - Poor scan (S4)

private struct PoorScanCard: View {
    let store: StoreOf<ScanFlow>

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Text("!")
                    .font(GRFont.archivo(20, weight: 800))
                    .foregroundStyle(GRColor.clay)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(GRColor.clayTint))
                Text("Not enough of the green")
                    .font(GRFont.archivo(26, weight: 800))
                Text("We covered \(Int((store.progress.coverage * 100).rounded()))%. Walk a little slower and sweep both sides of the line.")
                    .font(GRFont.archivo(15, weight: 500))
                    .foregroundStyle(GRColor.textSecondary)
                PillButton("Rescan gaps only", kind: .neutral) { store.send(.rescanGapsButtonTapped) }
                    .padding(.top, 4)
                TextLinkButton(title: "Start over", colour: GRColor.textSecondary) {
                    store.send(.startOverButtonTapped)
                }
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(GRColor.ink)
            .padding(22)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous).fill(.white)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
}

// MARK: - Result (3a)

private struct ScanResultCard: View {
    let store: StoreOf<ScanFlow>

    var body: some View {
        VStack {
            Spacer()
            if let result = store.result {
                let settings = store.settings
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 8) {
                        column("ACTUAL", settings.distance(feet: result.breakdown.feet))
                        column(
                            "PLAYS",
                            settings.distance(feet: result.playsLikeFeet),
                            note: hillNote(result.reading.hill),
                            noteColour: GRColor.clay
                        )
                        column(
                            "AIM",
                            settings.aim(inches: result.aimInches, side: result.aimSide).text,
                            colour: GRColor.green,
                            note: result.breakDirection == .straight ? "straight" : "breaks \(result.breakDirection.label)"
                        )
                    }
                    HStack(spacing: 8) {
                        PillButton("Rescan", kind: .secondary, height: 54) { store.send(.rescanButtonTapped) }
                        PillButton(store.isSaved ? "Saved ✓" : "Save", kind: .neutral, height: 54) {
                            store.send(.saveButtonTapped)
                        }
                        .disabled(store.isSaved)
                    }
                }
                .foregroundStyle(GRColor.ink)
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white))
                .padding(.horizontal, 14)
                .padding(.bottom, 18)
                .transition(.move(edge: .bottom))
                .sensoryFeedback(.success, trigger: store.isSaved) { _, isSaved in isSaved }
            }
        }
    }

    private func hillNote(_ hill: Hill) -> String? {
        switch hill {
        case .up: "▲ uphill"
        case .down: "▼ downhill"
        case .flat: nil
        }
    }

    private func column(
        _ label: String,
        _ value: String,
        colour: Color = GRColor.ink,
        note: String? = nil,
        noteColour: Color = GRColor.textSecondary
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).gr(.labelSmall).foregroundStyle(GRColor.textSecondary)
            Text(value)
                .font(GRFont.archivo(26, weight: 800))
                .foregroundStyle(colour)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let note {
                Text(note).font(GRFont.archivo(12, weight: 600)).foregroundStyle(noteColour)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Bright sun (S5)

private struct BrightSunBanner: View {
    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(GRColor.lime).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Strong sun").font(GRFont.archivo(17, weight: 800))
                Text("Stand so your shadow isn't on the line").font(GRFont.archivo(13, weight: 500))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(GRColor.ink))
        .overlay(alignment: .bottom) {
            Text("High-contrast mode on")
                .font(GRFont.archivo(15, weight: 800))
                .foregroundStyle(GRColor.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(.white))
                .offset(y: 34)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Green speed (S2)

struct GreenSpeedSheet: View {
    let store: StoreOf<GreenSpeedPicker>

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How fast is the green?").font(GRFont.archivo(26, weight: 800))
            HStack(spacing: 8) {
                ForEach(GreenSpeed.presets, id: \.self) { preset in
                    let isSelected = store.speed == preset
                    Button { store.send(.presetTapped(preset)) } label: {
                        VStack(spacing: 2) {
                            Text(preset.presetName ?? "").font(GRFont.archivo(17, weight: 800))
                            Text(preset.stimpLabel).font(GRFont.archivo(11, weight: 600)).opacity(0.7)
                        }
                        .foregroundStyle(isSelected ? Color.white : GRColor.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(isSelected ? GRColor.ink : GRColor.fill)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            if store.showsExactStimp {
                HStack {
                    Text("Exact Stimp").font(GRFont.archivo(15, weight: 600))
                    Spacer()
                    Button { store.send(.stimpMinusTapped) } label: { Image(systemName: "minus") }
                        .frame(width: GRMetrics.minTapTarget, height: GRMetrics.minTapTarget)
                    Text(store.speed.stimpLabel).font(GRFont.archivo(15, weight: 800)).monospacedDigit()
                    Button { store.send(.stimpPlusTapped) } label: { Image(systemName: "plus") }
                        .frame(width: GRMetrics.minTapTarget, height: GRMetrics.minTapTarget)
                }
                .foregroundStyle(GRColor.ink)
            } else {
                TextLinkButton(title: "Enter exact Stimp ›") { store.send(.exactStimpTapped) }
            }
            PillButton("Show my line", height: 58) { store.send(.showLineButtonTapped) }
        }
        .foregroundStyle(GRColor.ink)
        .padding(.horizontal, GRMetrics.screenPadding)
        .padding(.top, 24)
        .presentationDetents([.height(store.showsExactStimp ? 400 : 360)])
        .presentationBackground(.white)
        .presentationCornerRadius(32)
    }
}

// MARK: - No LiDAR (S3) and camera primer (S6)

private struct NoLiDARView: View {
    let useQuickRead: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 116)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GRColor.fillStrong)
                .frame(width: 72, height: 72)
                .overlay { Circle().strokeBorder(GRColor.textSecondary, lineWidth: 4).frame(width: 34, height: 34) }
                .accessibilityHidden(true)
            Text("AR Scan needs a LiDAR iPhone")
                .font(GRFont.archivo(30, weight: 800))
                .accessibilityAddTraits(.isHeader)
            Text("Pro models from iPhone 12 Pro have it. Quick Read works on any phone — and gives you the same aim number.")
                .font(GRFont.archivo(16, weight: 500))
                .foregroundStyle(GRColor.textSecondary)
            Spacer()
            PillButton("Use Quick Read", action: useQuickRead)
                .padding(.bottom, 8)
        }
        .foregroundStyle(GRColor.ink)
        .padding(.horizontal, GRMetrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GRColor.chalk.ignoresSafeArea())
    }
}

private struct CameraPrimerView: View {
    let isDenied: Bool
    let allow: () -> Void
    let openSettings: () -> Void
    let useQuickRead: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 116)
            StripedPlaceholder()
                .frame(height: 270)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    Text("PREVIEW · AR LINE ON GREEN").gr(.labelSmall).foregroundStyle(GRColor.textSecondary).padding(16)
                }
                .accessibilityHidden(true)
            Text("Let Scan see the green")
                .font(GRFont.archivo(34, weight: 800, width: 110))
                .padding(.top, 24)
                .accessibilityAddTraits(.isHeader)
            Text(
                isDenied
                    ? "Camera access is off. Turn it on in Settings to use Scan."
                    : "The camera maps slope in 3D. Nothing is recorded or uploaded."
            )
            .font(GRFont.archivo(16, weight: 500))
            .foregroundStyle(GRColor.textSecondary)
            .padding(.top, 8)
            Spacer()
            if isDenied {
                PillButton("Open Settings", action: openSettings)
            } else {
                PillButton("Allow camera", action: allow)
            }
            TextLinkButton(title: "Use Quick Read instead", colour: GRColor.textSecondary, action: useQuickRead)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
        }
        .foregroundStyle(GRColor.ink)
        .padding(.horizontal, GRMetrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GRColor.chalk.ignoresSafeArea())
    }
}
