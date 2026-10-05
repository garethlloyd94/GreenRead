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

            case .tool(.quickRead(.delegate(.close))):
                return .run { [dismiss] _ in await dismiss() }

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
        ZStack(alignment: .top) {
            switch store.scope(state: \.tool, action: \.tool).case {
            case let .quickRead(quickReadStore):
                QuickReadView(store: quickReadStore)
            case let .scan(scanStore):
                ScanView(store: scanStore)
            }
            chrome
                .padding(.horizontal, GRMetrics.screenPadding)
                .padding(.top, 4)
        }
        .background(GRColor.ink.ignoresSafeArea())
    }

    /// ✕ on the left, the tool-name pill (Scan ↔ Quick Read) in the centre.
    private var chrome: some View {
        HStack {
            CircleIconButton(systemName: "xmark", accessibilityLabel: "Close", floating: true) {
                store.send(.closeButtonTapped)
            }
            Spacer()
            Menu {
                ForEach(ToolFeature.ToolKind.allCases, id: \.self) { kind in
                    Button(kind.rawValue) { store.send(.switcherTapped(kind)) }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(store.toolKind.rawValue).font(GRFont.archivo(16, weight: 800))
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(GRColor.ink)
                .padding(.horizontal, 18)
                .frame(height: GRMetrics.minTapTarget)
                .background(Capsule().fill(.white))
                .floatingShadow()
            }
            .accessibilityLabel("Tool: \(store.toolKind.rawValue). Switch tool")
            Spacer()
            Color.clear.frame(width: GRMetrics.circleButton, height: GRMetrics.circleButton)
        }
    }
}

#Preview {
    ToolView(store: Store(initialState: ToolFeature.State.quickRead) { ToolFeature() })
}

extension ToolFeature.Tool.State: Equatable {}
