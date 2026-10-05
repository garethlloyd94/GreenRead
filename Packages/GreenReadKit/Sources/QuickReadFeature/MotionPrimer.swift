import Clients
import ComposableArchitecture
import DesignSystem
import SwiftUI
import UIKit

/// S7: asks for Motion & Fitness before the system prompt, and the "Open Settings" state
/// when access was turned off.
@Reducer
public struct MotionPrimer {
    @ObservableState
    public struct State: Equatable {
        public var isDenied: Bool

        public init(isDenied: Bool = false) {
            self.isDenied = isDenied
        }
    }

    public enum Action {
        case allowButtonTapped
        case appBecameActive
        case delegate(Delegate)
        case motionPermissionResponse(Bool)
        case notNowButtonTapped
        case openSettingsButtonTapped

        @CasePathable
        public enum Delegate {
            case granted
            case notNow
        }
    }

    @Dependency(\.openURL) var openURL
    @Dependency(PermissionsClient.self) var permissions

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .allowButtonTapped:
                return .run { [permissions] send in
                    await send(.motionPermissionResponse(permissions.requestMotion()))
                }

            case .appBecameActive:
                guard state.isDenied, permissions.motionStatus() == .authorized else { return .none }
                return .send(.delegate(.granted))

            case .delegate:
                return .none

            case let .motionPermissionResponse(granted):
                if granted {
                    return .send(.delegate(.granted))
                }
                state.isDenied = true
                return .none

            case .notNowButtonTapped:
                return .send(.delegate(.notNow))

            case .openSettingsButtonTapped:
                return .run { [openURL] _ in
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    await openURL(url)
                }
            }
        }
    }
}

struct MotionPrimerView: View {
    let store: StoreOf<MotionPrimer>
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 116)
            PhoneFlatIllustration()
                .frame(height: 220)
            Text("Let your phone feel the slope")
                .gr(.title)
                .foregroundStyle(GRColor.ink)
                .padding(.top, 24)
                .accessibilityAddTraits(.isHeader)
            Text(
                store.isDenied
                    ? "Motion access is off. Turn it on in Settings to use Quick Read."
                    : "Quick Read uses motion sensors to measure tilt when your phone lies flat. Only used during a read — nothing leaves your phone."
            )
            .gr(.body)
            .foregroundStyle(GRColor.textSecondary)
            .padding(.top, 8)
            Spacer()
            if store.isDenied {
                PillButton("Open Settings") { store.send(.openSettingsButtonTapped) }
            } else {
                PillButton("Allow motion") { store.send(.allowButtonTapped) }
            }
            TextLinkButton(title: "Not now", colour: GRColor.textSecondary) {
                store.send(.notNowButtonTapped)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, GRMetrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GRColor.chalk.ignoresSafeArea())
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.send(.appBecameActive) }
        }
    }
}

/// Green card with a phone lying flat and a lime triangle pointing up the screen.
private struct PhoneFlatIllustration: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(GRColor.green)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(GRColor.ink)
                    .frame(width: 96, height: 170)
                    .overlay {
                        Triangle()
                            .fill(GRColor.lime)
                            .frame(width: 44, height: 34)
                    }
                    .rotation3DEffect(.degrees(52), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                    .shadow(color: GRColor.ink.opacity(0.35), radius: 12, y: 10)
            }
            .accessibilityHidden(true)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
