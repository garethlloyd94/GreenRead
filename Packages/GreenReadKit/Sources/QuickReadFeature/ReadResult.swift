import ComposableArchitecture
import DesignSystem
import GreenReadCore
import Models
import SQLiteData
import SwiftUI

/// The Tour Read result card, the "How we got this" working, and New read / Save.
@Reducer
public struct ReadResult {
    @ObservableState
    public struct State: Equatable {
        public var feet: Double
        public var reading: SlopeReading
        public var speed: GreenSpeed
        public var isSaved = false
        public var isWorkingExpanded = false
        @SharedReader(.appSettings) public var settings

        public init(feet: Double, reading: SlopeReading, speed: GreenSpeed) {
            self.feet = feet
            self.reading = reading
            self.speed = speed
        }

        public var result: AimResult {
            TourRead.read(feet: feet, slope: reading, speed: speed)
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case newReadButtonTapped
        case saveButtonTapped

        @CasePathable
        public enum Delegate {
            case newRead
        }
    }

    @Dependency(\.date.now) var now
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding, .delegate:
                return .none

            case .newReadButtonTapped:
                return .send(.delegate(.newRead))

            case .saveButtonTapped:
                guard !state.isSaved else { return .none }
                state.isSaved = true
                let read = savedRead(state)
                return .run { [database] _ in
                    try await database.write { db in
                        try SavedRead.insert { read }.execute(db)
                    }
                }
            }
        }
    }
}

extension ReadResult {
    func savedRead(_ state: State) -> SavedRead {
        SavedRead(
            id: uuid(),
            savedAt: now,
            source: .quickRead,
            distanceFeet: state.feet,
            uphillPercent: state.reading.uphillPercent,
            sidePercent: state.reading.sidePercent,
            stimp: state.speed.stimp,
            aimInches: state.result.aimInches
        )
    }
}

struct ReadResultView: View {
    @Bindable var store: StoreOf<ReadResult>

    var body: some View {
        let result = store.result
        let settings = store.settings
        VStack(spacing: 10) {
            ResultCard(
                aim: settings.aim(inches: result.aimInches, side: result.aimSide),
                breakLabel: result.breakDirection == .straight ? nil : result.breakDirection.label,
                actual: settings.distance(feet: store.feet),
                plays: settings.distance(feet: result.playsLikeFeet),
                playsMarker: playsMarker(result.reading.hill),
                slope: Format.slope(percent: result.reading.sidePercent)
            )
            HowWeGotThisPanel(
                lines: workingLines(result.breakdown, unit: settings.aimUnit),
                total: settings.aim(inches: result.aimInches, side: result.aimSide).text,
                isExpanded: $store.isWorkingExpanded
            )
            Spacer()
            HStack(spacing: 8) {
                PillButton("New read", kind: .secondary) { store.send(.newReadButtonTapped) }
                PillButton(store.isSaved ? "Saved ✓" : "Save", kind: .neutral) { store.send(.saveButtonTapped) }
                    .disabled(store.isSaved)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 116)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GRColor.chalk.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: store.isSaved) { _, isSaved in isSaved && settings.hapticsOn }
    }

    private func playsMarker(_ hill: Hill) -> String? {
        switch hill {
        case .up: "▲"
        case .down: "▼"
        case .flat: nil
        }
    }
}

/// The Tour Read working, in the chosen aim unit.
func workingLines(_ breakdown: AimBreakdown, unit: AimUnit) -> [WorkingLine] {
    var lines = [
        WorkingLine(
            label: "\(Format.yards(feet: breakdown.feet)) × 2 − 1",
            value: "\(Format.aim(inches: breakdown.onePercentInches, unit: unit).amount) @1%"
        ),
        WorkingLine(
            label: "× \(breakdown.slopePercent)% slope",
            value: Format.aim(inches: breakdown.scaledInches, unit: unit).amount
        ),
    ]
    if breakdown.hill != .flat {
        lines.append(
            WorkingLine(
                label: breakdown.hill == .up ? "uphill adj." : "downhill adj.",
                value: Format.signedAim(inches: breakdown.hillAdjustmentInches, unit: unit)
            )
        )
    }
    if breakdown.hasSpeedAdjustment {
        lines.append(
            WorkingLine(
                label: "\(breakdown.speed.displayName.lowercased()) green",
                value: String(format: "× %.1f", breakdown.speed.breakFactor)
            )
        )
    }
    return lines
}
