# GreenRead

**Find the line.** A native iOS putting assistant (SwiftUI, iOS 17+, iPhone, portrait).

- Plan and decisions: [`docs/PLAN.md`](docs/PLAN.md)
- Design handoff (source of truth): [`docs/design/`](docs/design/) — open `prototype/Putting App Prototype.dc.html` in a browser

## Requirements

- Xcode 16 or later (Swift 6). Swift packages resolve on first open.
- iOS 17 device or simulator. Sensors (Quick Read), AR (Scan, LiDAR iPhones only) and audio timing (Tempo) need a real iPhone.

## Build and run

1. Open `GreenRead.xcodeproj`.
2. Select the **GreenRead** target → *Signing & Capabilities* → choose your Team. Bundle ID: `com.garethlloyd.greenread`.
3. Pick an iPhone simulator or your device and press Run.

In debug builds Home has a **Component gallery** link showing every design-system component.

Debug launch arguments (Scheme → Run → Arguments, or `xcrun simctl launch booted com.garethlloyd.greenread …`):
- `-hasSeenOnboarding '<true/>'` skips onboarding.
- `-screen settings|tempo|quickRead|quickRead.layFlat|quickRead.result|quickRead.train|train.guess|train.reveal|train.summary|scan|stats` opens that screen at launch.
- `-seedStats '<true/>'` adds four sample Train rounds so Stats is unlocked.
- In the Simulator, motion and step counting are scripted (a phone laid on a 1.2% uphill, 2.1% R→L green), so Quick Read runs end to end.

## Tests

All tests use Swift Testing.

- **`GreenReadCore`** — Tour Read maths, unit formatting and other pure logic:
  ```sh
  cd Packages/GreenReadCore && swift test
  ```
- **`GreenReadKit`** — TCA feature tests (`TestStore`, every navigation route) and database tests. iOS-only, so run on a simulator:
  ```sh
  cd Packages/GreenReadKit
  xcodebuild test -scheme GreenReadKit-Package -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -skipMacroValidation
  ```
  Or open `Packages/GreenReadKit/Package.swift` in Xcode and press ⌘U.

## Architecture

The Composable Architecture (TCA), SQLiteData for records and `@Shared` (Sharing) for settings. See [`docs/PLAN.md` §2](docs/PLAN.md#2-architecture) for the navigation map.

```
GreenRead.xcodeproj/
GreenRead/                   thin app target: @main, Info.plist settings, app icon
Packages/GreenReadKit/       everything else, one module per area
  DesignSystem/              tokens, components, fonts (SIL OFL), Colors.xcassets, debug gallery
  Models/                    SQLiteData tables + migrations, @Shared keys (settings, onboarding, tempo)
  Clients/                   @DependencyClient sensor/permission clients
  AppFeature/                root reducer: Home + destination + path
  HomeFeature, OnboardingFeature, QuickReadFeature, ScanFeature, ToolFeature,
  StatsFeature, TempoFeature, DrillsFeature, SettingsFeature
Packages/GreenReadCore/      pure Swift logic + tests (no dependencies, no UIKit)
docs/                        plan and design handoff
```

Fonts: Archivo and JetBrains Mono are bundled under the SIL Open Font License 1.1 (licences alongside the font files).
