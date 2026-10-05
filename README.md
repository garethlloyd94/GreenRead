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

## Accessibility

All text scales with Dynamic Type: use `.gr(.style)` for named text styles and `.grFont(.archivo(…))` for one-off sizes, never `.font(GRFont.archivo(…))` directly. Display sizes (28pt and up) are capped at 140% so hero numbers stay on one line.

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

CI (`.github/workflows/ci.yml`) runs both on every pull request: `GreenReadCore` on Linux, `GreenReadKit` on an iOS simulator.

## Dependencies

Dependency versions are pinned by the committed `Package.resolved` files (the app's lives in `GreenRead.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`). After changing or updating a package, commit the updated `Package.resolved` too.

## Database

Records live in SQLite (SQLiteData); migrations are in `Packages/GreenReadKit/Sources/Models/Database.swift`.

- **Debug builds erase the database whenever the schema or a migration changes** (`eraseDatabaseOnSchemaChange`), so expect test rounds and saved reads to disappear after a schema edit.
- Release builds never erase. Once a migration has shipped, never edit it: add a new one (`v2`, `v3`…).
- If the database can't be opened at launch, the app logs a fault and runs on an in-memory database for that session.

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
