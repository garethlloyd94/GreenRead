import ComposableArchitecture
import DesignSystem
import QuickReadFeature
import ScanFeature
import SwiftUI

/// The full-screen tool modal: ✕, the Scan ↔ Quick Read switcher pill, and the current tool.
/// Switching tools replaces the case, which cancels the outgoing tool's effects.
@Reducer
public struct ToolFeature {
    @ObservableState
    public struct State: Equatable {
        public var tool: Tool.State

        public init(tool: Tool.State) {
            self.tool = tool
        }

        public static var quickRead: Self { Self(tool: .quickRead(QuickReadFeature.State())) }
        public static var scan: Self { Self(tool: .scan(ScanFlow.State())) }

        public var toolKind: ToolKind {
            switch tool {
            case .quickRead: .quickRead
            case .scan: .scan
            }
        }
    }

    @Reducer
    public enum Tool {
        case quickRead(QuickReadFeature)
        case scan(ScanFlow)
    }

    public enum ToolKind: String, CaseIterable, Sendable {
        case scan = "Scan"
        case quickRead = "Quick Read"
    }

    public enum Action {
        case closeButtonTapped
        case delegate(Delegate)
        case switcherTapped(ToolKind)
        case tool(Tool.Action)

        @CasePathable
        public enum Delegate {
            case showStats
        }
    }

    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        Scope(state: \.tool, action: \.tool) {
            Tool.body
        }
        Reduce { state, action in
            switch action {
            case .closeButtonTapped:
                return .run { [dismiss] _ in await dismiss() }

            case .delegate:
                return .none

            case let .switcherTapped(kind):
                guard kind != state.toolKind else { return .none }
                state = kind == .scan ? .scan : .quickRead
                return .none

            case .tool(.quickRead(.delegate(.showStats))):
                return .send(.delegate(.showStats))

            case .tool(.scan(.delegate(.switchToQuickRead))):
                state = .quickRead
                return .none

            case .tool:
                return .none
            }
        }
    }
}

public struct ToolView: View {
    let store: StoreOf<ToolFeature>

    public init(store: StoreOf<ToolFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 20) {
            HStack {
                CircleIconButton(systemName: "xmark", accessibilityLabel: "Close") {
                    store.send(.closeButtonTapped)
                }
                Spacer()
                Menu {
                    ForEach(ToolFeature.ToolKind.allCases, id: \.self) { kind in
                        Button(kind.rawValue) { store.send(.switcherTapped(kind)) }
                    }
                } label: {
                    Text(store.toolKind.rawValue)
                        .gr(.button)
                        .foregroundStyle(GRColor.ink)
                        .padding(.horizontal, 18)
                        .frame(height: GRMetrics.minTapTarget)
                        .background(Capsule().fill(.white))
                }
                .accessibilityLabel("Switch tool")
                Spacer()
                Color.clear.frame(width: GRMetrics.circleButton, height: GRMetrics.circleButton)
            }
            switch store.scope(state: \.tool, action: \.tool).case {
            case let .quickRead(quickReadStore):
                QuickReadView(store: quickReadStore)
            case let .scan(scanStore):
                ScanView(store: scanStore)
            }
        }
        .padding(GRMetrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GRColor.turfDark.ignoresSafeArea())
    }
}

#Preview {
    ToolView(store: Store(initialState: ToolFeature.State.quickRead) { ToolFeature() })
}

extension ToolFeature.Tool.State: Equatable {}
