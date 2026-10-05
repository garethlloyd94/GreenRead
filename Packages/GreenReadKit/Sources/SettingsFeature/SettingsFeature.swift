import ComposableArchitecture
import DesignSystem
import GreenReadCore
import Models
import SwiftUI

/// Settings sheet. Every control binds straight to the shared settings; the full layout lands in M2.
@Reducer
public struct SettingsFeature {
    @ObservableState
    public struct State: Equatable {
        @Shared(.appSettings) public var settings

        public init() {}
    }

    public enum Action {
        case doneButtonTapped
    }

    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .doneButtonTapped:
                return .run { [dismiss] _ in await dismiss() }
            }
        }
    }
}

public struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Settings").gr(.title)
                Spacer()
                TextLinkButton(title: "Done") { store.send(.doneButtonTapped) }
            }
            Text("AIM UNIT").gr(.label).foregroundStyle(GRColor.textSecondary)
            PillSegmentedControl(
                options: AimUnit.allCases,
                selection: Binding(store.state.$settings.aimUnit),
                style: .settings
            ) { $0.title }
            Spacer()
        }
        .padding(GRMetrics.screenPadding)
        .background(GRColor.chalk)
    }
}

#Preview {
    SettingsView(store: Store(initialState: SettingsFeature.State()) { SettingsFeature() })
}
