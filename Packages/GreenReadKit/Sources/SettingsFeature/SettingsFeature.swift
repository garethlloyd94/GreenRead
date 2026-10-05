import ComposableArchitecture
import DesignSystem
import GreenReadCore
import Models
import SwiftUI

/// Settings sheet. Segments and toggles bind straight to the shared settings; steppers go
/// through the reducer so their limits are tested.
@Reducer
public struct SettingsFeature {
    @ObservableState
    public struct State: Equatable {
        @Shared(.appSettings) public var settings

        public init() {}
    }

    public enum Action {
        case greenSpeedMinusTapped
        case greenSpeedPlusTapped
        case paceLengthMinusTapped
        case paceLengthPlusTapped
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .greenSpeedMinusTapped:
                state.$settings.withLock { $0.stepDefaultSpeed(by: -1) }
                return .none

            case .greenSpeedPlusTapped:
                state.$settings.withLock { $0.stepDefaultSpeed(by: 1) }
                return .none

            case .paceLengthMinusTapped:
                state.$settings.withLock { $0.stepPaceLength(by: -1) }
                return .none

            case .paceLengthPlusTapped:
                state.$settings.withLock { $0.stepPaceLength(by: 1) }
                return .none
            }
        }
    }
}

public struct SettingsView: View {
    let store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Settings").gr(.title)
                    .padding(.top, 20)
                VStack(spacing: 0) {
                    SettingsRow("Units", showsDivider: false) {
                        PillSegmentedControl(
                            options: DistanceUnit.allCases,
                            selection: Binding(store.state.$settings.distanceUnit),
                            style: .settings
                        ) { $0.shortLabel }
                    }
                    SettingsRow("Aim unit") {
                        PillSegmentedControl(
                            options: AimUnit.allCases,
                            selection: Binding(store.state.$settings.aimUnit),
                            style: .settings
                        ) { $0.title }
                    }
                    SettingsRow("Default green speed") {
                        SettingsStepper(
                            value: store.settings.defaultSpeed.displayName,
                            accessibilityLabel: "Default green speed",
                            canDecrement: store.settings.defaultSpeed.stimp > GreenSpeed.stimpRange.lowerBound,
                            canIncrement: store.settings.defaultSpeed.stimp < GreenSpeed.stimpRange.upperBound,
                            decrement: { store.send(.greenSpeedMinusTapped) },
                            increment: { store.send(.greenSpeedPlusTapped) }
                        )
                    }
                    SettingsRow("Pace length") {
                        SettingsStepper(
                            value: store.settings.paceLengthLabel,
                            accessibilityLabel: "Pace length",
                            canDecrement: store.settings.paceLengthFeet > AppSettings.paceLengthRange.lowerBound,
                            canIncrement: store.settings.paceLengthFeet < AppSettings.paceLengthRange.upperBound,
                            decrement: { store.send(.paceLengthMinusTapped) },
                            increment: { store.send(.paceLengthPlusTapped) }
                        )
                    }
                    SettingsRow {
                        Toggle("Sounds", isOn: Binding(store.state.$settings.soundsOn))
                            .toggleStyle(GRToggleStyle())
                    }
                    SettingsRow {
                        Toggle("Haptics", isOn: Binding(store.state.$settings.hapticsOn))
                            .toggleStyle(GRToggleStyle())
                    }
                }
                .grFont(.archivo(15, weight: 600))
                .foregroundStyle(GRColor.ink)
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(GRColor.card))

                (Text("Practice & casual play only.").bold()
                    + Text(" Slope-reading devices aren't allowed in competitive rounds under the Rules of Golf."))
                    .grFont(.archivo(13, weight: 500))
                    .lineSpacing(3)
                    .foregroundStyle(GRColor.clayTintText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(GRColor.clayTint))
            }
            .padding(.horizontal, GRMetrics.screenPadding)
            .padding(.bottom, 34)
        }
        .presentationBackground(GRColor.chalk)
        .presentationDetents([.height(600), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }
}

/// One 56pt row in the Settings card, with a hairline above every row but the first.
private struct SettingsRow<Accessory: View>: View {
    var title: String?
    var showsDivider = true
    @ViewBuilder let accessory: Accessory

    init(_ title: String? = nil, showsDivider: Bool = true, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.showsDivider = showsDivider
        self.accessory = accessory()
    }

    var body: some View {
        HStack {
            if let title {
                Text(title)
                Spacer()
            }
            accessory
        }
        .frame(minHeight: 56)
        .overlay(alignment: .top) {
            if showsDivider {
                Rectangle().fill(GRColor.fill).frame(height: 1)
            }
        }
    }
}

/// "− Medium +": a value with small round buttons inside 48pt tap targets.
private struct SettingsStepper: View {
    let value: String
    let accessibilityLabel: String
    let canDecrement: Bool
    let canIncrement: Bool
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus", enabled: canDecrement, action: decrement)
            Text(value)
                .foregroundStyle(GRColor.textSecondary)
                .monospacedDigit()
                .frame(minWidth: 64)
            stepButton("plus", enabled: canIncrement, action: increment)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(value)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if canIncrement { increment() }
            case .decrement: if canDecrement { decrement() }
            @unknown default: break
            }
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(GRColor.ink)
                .frame(width: 30, height: 30)
                .background(Circle().fill(GRColor.fill))
                .frame(width: GRMetrics.minTapTarget, height: GRMetrics.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        SettingsView(store: Store(initialState: SettingsFeature.State()) { SettingsFeature() })
    }
}
