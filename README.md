# GreenRead

**Find the line.** A native iOS putting assistant (SwiftUI, iOS 17+, iPhone, portrait).

- Plan and decisions: [`docs/PLAN.md`](docs/PLAN.md)
- Design handoff (source of truth): [`docs/design/`](docs/design/) — open `prototype/Putting App Prototype.dc.html` in a browser

## Requirements

- Xcode 16 or later (the project uses folder-synchronised groups, so new files under `GreenRead/` are picked up automatically)
- iOS 17 device or simulator. Sensors (Quick Read), AR (Scan, LiDAR iPhones only) and audio timing (Tempo) need a real iPhone.

## Build and run

1. Open `GreenRead.xcodeproj`.
2. Select the **GreenRead** target → *Signing & Capabilities* → choose your Team. Bundle ID: `com.garethlloyd.greenread`.
3. Pick an iPhone simulator or your device and press Run.

In debug builds the first screen has an **Open component gallery** button showing every design-system component.

## Tests

The Tour Read maths, unit formatting and other pure logic live in the `GreenReadCore` Swift package, with unit tests.

```sh
cd Packages/GreenReadCore
swift test
```

Or in Xcode: open `Packages/GreenReadCore/Package.swift` and press ⌘U.

## Layout

```
GreenRead.xcodeproj/
GreenRead/                 app target (synchronised folder)
  App/                     app entry, root view
  DesignSystem/            colour, type, metrics, components, debug gallery
  Persistence/             SwiftData models
  Resources/               fonts (Archivo, JetBrains Mono — SIL OFL), asset catalog
Packages/GreenReadCore/    pure Swift logic + tests (no UIKit)
docs/                      plan and design handoff
```

Fonts: Archivo and JetBrains Mono are bundled under the SIL Open Font License 1.1 (licences alongside the font files).
