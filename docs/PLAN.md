# GreenRead — Build Plan (for approval)

**App:** GreenRead — "Find the line."
**Platform:** Native iOS, SwiftUI, iOS 17+, iPhone only (portrait).
**Frameworks:** SwiftUI · The Composable Architecture (TCA) · SQLiteData · Sharing · CoreMotion · ARKit/RealityKit · AVAudioEngine · Core Haptics · WebKit (YouTube player only).
**Source of truth:** `docs/design/` — README spec, then `prototype/Putting App Prototype.dc.html`, then `reference/Putting App Design Pack.html` for screens the prototype covers lightly.

Status: **REVISION 4 — architecture moved to TCA (see §0); all decisions made.** Designs: design pack 3 (`User_flow_and_screen_options_3.zip`). Visual version with every screen: https://claude.ai/artifact/2qBkK3YWoEtsbH4pab11FR

---

## 0. What changed in revision 4

| Area | Rev 3 | Rev 4 | Why |
|---|---|---|---|
| State and navigation | One `@Observable AppState` router plus a view model per feature | TCA: a root `AppFeature` with `@Presents var destination` (an enum) and a `StackState` path; one `@Reducer` per feature | Navigation is modelled as state, so every route (including "Stats from the Train summary") is testable with `TestStore` |
| Step machines | A `step` value inside each view model | A `@Reducer enum` per flow (`ReadFlow.Step`, `TrainFlow.Step`, `ScanFlow.Step`); each case is its own feature | Each step owns only the state it needs; invalid combinations can't be represented |
| Persistence | SwiftData for everything | **SQLiteData** for records (rounds, putts, reads, saved videos); **`@Shared`** for settings and flags | SwiftData doesn't fit TCA's value-type state or its tests; SQLiteData works through `@Dependency(\.defaultDatabase)` and `@FetchAll` |
| Services | Classes (`MotionService`, `TempoEngine`…) | `@DependencyClient` structs with live, preview and test values | Swap in scripted sensors in previews, tests and the Simulator |
| Aim formatting | An `AimFormatter` environment value | Derived from `@Shared(.appSettings)` | One source of truth that both reducers and views read |
| Permission primers | First-time flags | Driven by authorisation status from a `PermissionsClient` (`.notDetermined` → primer, `.denied` → Settings state) | No flags to get out of sync with iOS |
| Tests | XCTest | Swift Testing + `TestStore` + `expectNoDifference` (CustomDump) | Exhaustive feature tests; clearer failure diffs |
| Workflow | Cloud Linux, can't build iOS | Local Mac, Xcode 27, Xcode MCP connected | I can now build, run tests and catch compile errors myself |

---

## 1. What we're building

A putting assistant used on the practice green: one-handed, often in bright sun. Big tap targets (48pt minimum), high contrast, results you can read at a glance.

| Tool | What it does | Presented as |
|---|---|---|
| **Scan** | LiDAR AR scan of the green: mark ball and hole, walk the line, pick green speed, see a curved break line and aim point on the real green. | Full-screen modal |
| **Quick Read — Read** | Measure distance, lay the phone flat aimed at the hole, read slope with CoreMotion, get the Tour Read aim plus a "How we got this" panel. | Full-screen modal |
| **Quick Read — Train** | 5-putt game: measure, guess, lay flat (numbers hidden), reveal; then a round summary and score out of 100. | Same modal, Read \| Train switch |
| **Stats** | Read tendencies across rounds; locked until 3 rounds are done. | Pushed screen |
| **Tempo** | Metronome (pendulum, 60–100 BPM, separate back and through sounds, haptics), backswing drill, practice session. | Bottom sheet |
| **Drills & Tips** | Curated YouTube library: category chips, save/♥, in-app player, "Start tempo". | Home "Drills" segment |
| **Settings** | Units, aim unit, default green speed, pace length, haptics, Rules of Golf disclaimer. | Bottom sheet |

Navigation follows option **Nd**: no tab bar. Home shows the wordmark and tagline, then a **Play | Drills** segmented switch with a ⚙ button. Play is a list of tiles: Scan (hero), Quick Read, Tempo, Stats.

Onboarding follows option **1b**: a single-page tour ("Four tools. Find the line."). Camera and motion permissions are asked in context the first time Scan or Quick Read opens, using primer screens (S6 camera, S7 motion) before the system prompt.

---

## 2. Architecture

```
GreenRead/                           ← repo root
├─ GreenRead.xcodeproj               ← hand-written; thin app target
├─ GreenRead/                        ← app target: @main, Info.plist, assets, bootstrap only
│  └─ App/GreenReadApp.swift         prepareDependencies { bootstrapDatabase() }, Store(AppFeature)
├─ Packages/GreenReadKit/            ← local SPM package: everything except the @main entry
│  ├─ DesignSystem                   tokens, components, fonts (Bundle.module), gallery
│  ├─ Models                         SQLiteData @Table types, migrations, bootstrapDatabase,
│  │                                 SharedKeys (.appSettings, .hasSeenOnboarding, .tempoBPM)
│  ├─ Clients                        @DependencyClient interfaces + live values:
│  │                                 MotionClient, PedometerClient, PermissionsClient,
│  │                                 ARMeasureClient, GreenScanClient, TempoClient,
│  │                                 HapticsClient, DrillCatalogClient
│  ├─ AppFeature                     root reducer: Home, Destination, Path
│  ├─ HomeFeature                    Play tiles, Play|Drills switch, DrillsFeed
│  ├─ OnboardingFeature              1b tour
│  ├─ PermissionsFeature             S6/S7 primers + denied state
│  ├─ QuickReadFeature               ReadFlow, TrainFlow, Measure, LayFlat, Result, Guess…
│  ├─ ScanFeature                    ScanFlow, Mark, Scanning, GreenSpeed, Result, edge states
│  ├─ StatsFeature · TempoFeature · DrillsFeature (Player) · SettingsFeature
│  └─ Tests/                         one test target per feature (Swift Testing + TestStore)
├─ Packages/GreenReadCore/           ← pure Swift, no dependencies, no UIKit/ARKit
│  ├─ TourRead, Units, GreenSpeed    (done in M0)
│  ├─ SlopeReader                    attitude samples → stability state + averaged slope
│  ├─ TrainScoring · StatsEngine
│  └─ Tests/                         Swift Testing
└─ docs/
```

### 2.1 State: TCA

- **One root `AppFeature`.** `HomeFeature` is scoped in permanently; everything else is either a **destination** (modal) or on the **path** (pushed).
- **Every action is named after what the user did** (`scanTileTapped`, `closeButtonTapped`) or what came back (`motionUpdate`, `scanEvent`). Children talk to parents through `delegate` actions, never by reaching into parent state.
- **Child dismissal:** `@Dependency(\.dismiss)`, for the ✕ button and "Not now".
- **Dependencies are controlled:** `\.continuousClock`, `\.date.now`, `\.uuid`, `\.openURL` (for "Open Settings") are never called uncontrolled.

### 2.2 Navigation map

```swift
@Reducer struct AppFeature {
  @ObservableState struct State {
    var home = HomeFeature.State()
    var path = StackState<AppPath.State>()
    @Presents var destination: AppDestination.State?
  }
}

@Reducer enum AppPath {            // pushed full-screen with ‹ back (README: "Stats and video player push")
  case stats(StatsFeature)
  case player(PlayerFeature)
}

@Reducer enum AppDestination {
  case onboarding(OnboardingFeature)   // fullScreenCover on launch when !hasSeenOnboarding
  case tool(ToolFeature)               // fullScreenCover: Scan / Quick Read modal
  case tempo(TempoFeature)             // sheet
  case settings(SettingsFeature)       // sheet
}
```

- **`ToolFeature`** owns the shared modal chrome (✕ and the Scan ↔ Quick Read switcher pill). Its state is `var tool: Tool.State`, where `@Reducer enum Tool { case scan(ScanFlow), quickRead(QuickReadFeature) }`. Switching tools replaces the case, so the outgoing flow's effects (AR session, motion updates) are cancelled automatically.
- **`QuickReadFeature`** holds the Read | Train switch: `@Reducer enum Mode { case read(ReadFlow), train(TrainFlow) }`.
- **Step machines are enum reducers, not navigation stacks.** Steps replace each other in place with the prototype's transitions; there's no back-swipe between steps.
  - `ReadFlow.Step`: `primer(MotionPrimer) → measure(Measure) → layFlat(LayFlat) → result(ReadResult)`
  - `TrainFlow.Step`: `primer → measure → guess(Guess) → layFlat(hidden) → reveal(Reveal) → summary(Summary)`. The round (`IdentifiedArrayOf<TrainPutt>`) lives on `TrainFlow.State`, not in a step.
  - `ScanFlow.Step`: `noLiDAR | cameraPrimer → mark(Mark) → scanning(Scanning) → result(ScanResult)`. The green speed sheet is `@Presents var greenSpeed` on `ScanFlow`. Poor scan (S4) is a step-local state; bright sun (S5) is a flag driven by `GreenScanClient` events.
- **Cross-tree routes go through the root via delegates:**
  - Train Summary "See stats" → `.delegate(.showStats)` → `AppFeature` sets `destination = nil` and appends `.stats` to the path.
  - S3 "Use Quick Read instead" → `ToolFeature` swaps `tool` to `.quickRead`.
  - Player "Start tempo" → `PlayerFeature` has its own `@Presents var tempo: TempoFeature.State?`, so the sheet appears over the player as designed.
- **Views:** `NavigationStack(path: $store.scope(state: \.path, action: \.path))` at the root; `.fullScreenCover(item: $store.scope(state: \.destination?.tool, action: \.destination.tool))` and so on for each destination. Enum steps are rendered with `switch store.case { … }`.

### 2.3 Sensors and the store

High-rate data never goes through the store one sample at a time.
- **`MotionClient`** streams attitude at 60 Hz into `SlopeReader` (a pure state machine in Core) inside the client's effect. The reducer only gets **state changes** (`.tilted`, `.flatAndStill`, `.reading(progress)`, `.done(SlopeReading)`) plus a throttled (~10 Hz) live value for the orange/green screen.
- **`GreenScanClient`** owns the `ARSession`. The `ARView` representable is handed the session to display, and the reducer receives throttled `ScanEvent`s (coverage %, gap prompts, light estimate, quality), plus the final `GreenSurface` height field.
- **`TempoClient`** owns `AVAudioEngine`. Beats are scheduled on audio time and the pendulum animates from the client's `AsyncStream<BeatPhase>`. The reducer only handles Start/Stop/BPM.
- Each client has a **`previewValue` that scripts realistic data** (a phone being laid flat, a scan filling up, beats at the current BPM). Previews and the Simulator can run every flow end to end, and a DEBUG setting switches live clients to scripted ones.

### 2.4 Persistence

- **`@Shared` (Sharing)** for small values:
  - `@Shared(.appSettings)`: a `Codable` `AppSettings` struct in `fileStorage`. Units, aim unit, default Stimp, pace length, haptics, sounds.
  - `@Shared(.hasSeenOnboarding)` and `@Shared(.tempoBPM)` (the Home Tempo tile shows the live BPM): both `appStorage`.
- **SQLiteData** for records:
  - Tables: `trainRound`, `trainPutt`, `savedRead`, `savedVideo`.
  - `bootstrapDatabase()` runs in `GreenReadApp.init` via `prepareDependencies`, with migrations from day one and `eraseDatabaseOnSchemaChange` in DEBUG.
  - Stats reads with `@FetchAll` in `StatsFeature.State`; the Home Stats tile uses `@FetchOne` (round count and latest accuracy).
  - The maths stays in `StatsEngine`; SQL only filters and sorts.
- **Removes:** the SwiftData `AppSettings` `@Model` and `.modelContainer` from M0. There are no installs to migrate yet.

### 2.5 Unchanged from rev 3
- **No backend, no account, no analytics.** Fully offline except YouTube playback. The S6 copy promises "Nothing is recorded or uploaded."
- **Fonts:** Archivo (variable, width axis) and JetBrains Mono, OFL, bundled. They move into the `DesignSystem` target and register from `Bundle.module`.
- **Core stays dependency-free.** TCA, Sharing and SQLiteData are only linked by `GreenReadKit`.

### 2.6 Packages and settings
- `swift-composable-architecture` 1.x (brings Sharing, Dependencies, CasePaths, SwiftNavigation and IdentifiedCollections), `sqlite-data` 1.x, `swift-custom-dump` (tests only).
- Test targets link only `DependenciesTestSupport` and `CustomDump`, never `Dependencies` or `ComposableArchitecture` directly. Those come transitively and would double-link.
- Swift 6 language mode for `GreenReadKit` (the app target follows). iOS 17 deployment target stays: TCA's observation works natively on 17, so there's no Perception back-port.

### 2.7 Colours in an asset catalog
- **Move every `GRColor` hex value** into `DesignSystem/Resources/Colors.xcassets` as named colour sets. Use Xcode's generated `ColorResource` symbols, so `GRColor.ink` becomes `Color(.ink)`, with no string names to mistype.
- **`GRColor` stays as the semantic API.** Call sites don't change.
- **Why:**
  - **Increase Contrast variants per colour.** These are built into the asset catalog, matter for bright sun, and pair with S5.
  - **Display P3 for `lime`.** The AR overlay is meant to pop on OLED.
  - **Dark mode later is a data change, not a code change.**
  - **Same colours outside SwiftUI.** RealityKit materials and UIKit get them via `UIColor(resource:)`.
- **Hex init:** `Color(hex:)` stays only for preview-only stripes, or is removed.

---

## 3. Core maths (from the README and prototype; to be unit-tested)

**Aim (Tour Read):**
```
yards = feet / 3
base  = max(1, round(yards × 2 − 1))          // inches at 1%
aim   = base × slope%
uphill → aim −= slope% ; downhill → aim += slope%
aim   = max(0, round(aim))                     // stored in inches
```
Example: 15 ft → 5 yd → 9 in → ×2 = 18 → uphill −2 → **16 in R**. This is a unit test.

**Display units (display only; values are stored in inches and feet):**
- cups = in / 4.25, rounded to 0.5 ("1 cup" / "1.5 cups")
- balls = in / 1.68, rounded to an integer
- metres = ft × 0.3048, to one decimal place

**Slope from CoreMotion** (phone flat, top edge pointing at the hole):
- uphill % = tan(pitch) × 100 (positive = uphill toward the hole)
- side % = tan(roll) × 100. The break goes toward the low side: if the left side is low, the break is **R→L**.
- Flat + aimed is detected when the phone is near-flat (tilt under ~6°) and attitude variance stays below a threshold for ~1 s. Then readings are averaged over a short window ("Reading…") and the flow auto-advances.
- "Aimed": trust the golfer (Q3, option A). "Flat and held still for ~1 s" ticks both Flat ✓ and Aimed ✓.

**Train scoring** (from the prototype logic):
- Spot on = slope matches and direction correct · Wrong way = direction wrong · Under-read = guessed slope too low · Over-read = guessed slope too high
- Points: 20 / 12 / 5 for a slope error of 0 / 1 / 2+; −5 for the wrong break direction (minimum 0). 5 putts → score out of 100.
- Tendency: "You tend to under-read — trust more break." / "…over-read — play a little less break." / "Nicely balanced reads this round."

---

## 4. Screen inventory (what I'll build)

| # | Screen | Design source |
|---|---|---|
| 1 | Onboarding tour | Design pack 1b |
| 2 | Home — Play tiles | Prototype / Nd |
| 3 | Home — Drills feed + chips | Prototype / 12a list rows |
| 4 | Settings sheet | Prototype + design pack Settings |
| 5 | Camera / motion permission primers (+ motion denied state) | S6, S7 (design pack 3) |
| 6 | Modal chrome: ✕, tool-name switcher pill, Read \| Train | Prototype / M2 |
| 7 | QR Measure: AR tap · Walk it off · Enter manually | Prototype, Q1–Q3 |
| 8 | QR Lay flat: orange/green full-screen state | Prototype / 4c |
| 9 | QR Result card + "How we got this" | Prototype / 5a |
| 10 | Train Guess (chip form) | Prototype / 6a |
| 11 | Train Lay flat, numbers hidden | Q4 |
| 12 | Train Reveal (side-by-side) | Prototype / 7a |
| 13 | Train Round summary | Prototype / 8a |
| 14 | Stats: locked empty state and unlocked insight + diverging bars | Q5 / 9a |
| 15 | Tempo sheet: metronome only (MVP) | Prototype / 10a without the tabs |
| 16 | Video player (YouTube embed, Save, Start tempo, Up next) | D1 |
| 17 | Scan Mark ball and hole | Prototype / S1 |
| 18 | Scanning (paint overlay + ring + prompt pill) | Prototype / 2a |
| 19 | Green speed sheet | Prototype / S2 |
| 20 | Scan Result (curved lime line, aim ring, card) | Prototype / 3a |
| 21 | Edge states: no LiDAR (S3), poor scan (S4), bright sun (S5) | Design pack |

---

## 5. Milestones (build order from PROMPT.md)

Each milestone ends with a commit on a feature branch and a short note on what to check in Xcode or the Simulator.

**M0 — Project skeleton** ✅ (merged, PR #1)
Xcode project (folder-synchronised), app target and local `GreenReadCore` package (Tour Read maths, units, formatting), bundled fonts, design handoff in `docs/design/`, `swift test` for Core, README.

**M1 — Design system** ✅ (merged, PR #1)
Tokens; `Wordmark`; `PillButton`, `Chip`, `PillSegmentedControl`, cards, `VerdictBanner`, `DivergingBar`, `VideoRow`, `PopIn`; DEBUG component gallery.

**M1.5 — Architecture foundation**
- **`GreenReadKit` package:** create it and move `DesignSystem` into it, with fonts as package resources registered from `Bundle.module`.
- **Colours:** move them into an asset catalog in the `DesignSystem` target (see §2.7).
- **Dependencies:** add TCA, SQLiteData and CustomDump.
- **Persistence:** `Models` target with `bootstrapDatabase()`, the first migration (`trainRound`, `trainPutt`, `savedRead`, `savedVideo`) and the `SharedKey`s. Delete the SwiftData `AppSettings` and `.modelContainer`.
- **Clients:** `Clients` target with `PermissionsClient` (live). The other clients (Motion, Pedometer, ARMeasure, GreenScan, Tempo, Haptics, DrillCatalog) land with the milestone that first uses them, so their interfaces are shaped by real use.
- **Navigation skeleton:**
  - `AppFeature` with `AppDestination` and `AppPath`.
  - `ToolFeature` with the switcher pill and placeholder Scan / Quick Read flows.
  - Every route reachable: tiles → modal, ⚙ → Settings, Tempo tile → sheet, Stats tile → push.
- **Tests:**
  - Core tests: migrate XCTest → Swift Testing.
  - `BaseSuite` with `.dependencies { try $0.bootstrapDatabase() }`.
  - `TestStore` tests for every route in §2.2, including Summary → Stats.

**M2 — Home + Settings + Onboarding**
- **Home:** Play | Drills switch and tiles. The Tempo subtitle reads `@Shared(.tempoBPM)`; the Stats tile uses `@FetchOne` for "x/3 rounds" or the accuracy figure.
- **Settings:** the sheet binds straight to `@Shared(.appSettings)` (all controls, Rules of Golf box).
- **Onboarding:** 1b, shown on launch via `@Shared(.hasSeenOnboarding)`.
- **Aim formatting:** aim and distance formatting read the shared settings, so changing the unit updates every screen.

**M3 — Quick Read: Read**
- **Core:** `SlopeReader` (stability, averaging, sign conventions), with tests.
- **Clients:** live `MotionClient` (CMMotionManager, 60 Hz, events only as in §2.3) and `PermissionsClient`.
- **Flow:** S7 primer and the denied state, then `ReadFlow` steps.
- **Measure:** `ARMeasureClient` raycast tap (any iPhone), `PedometerClient` walk-off with pace length, manual stepper.
- **Screens:** the lay-flat state screen, and the result card with the pop animation and working panel.
- **Save:** Save → `savedRead` row.
- **Tests:** `TestStore` tests drive the whole flow with a scripted `MotionClient`.

**M4 — Quick Read: Train + Stats**
- **Flow:** `TrainFlow` (guess, hidden lay-flat, reveal, summary). `TrainScoring` + `StatsEngine` in Core, with tests.
- **Persistence:** the round is written on summary.
- **Stats:** `StatsFeature` with `@FetchAll`, locked/unlocked states and the Swift Charts trend.
- **Routes:** Play again; Stats from summary via delegate.

**M5 — Tempo**
- **Engine:** live `TempoClient` on AVAudioEngine with sample-accurate scheduling (buffers scheduled ahead against `AVAudioTime`, not timers) and distinct back and through sounds.
- **Feel:** `HapticsClient` (Core Haptics) synced to the beat; the pendulum is driven by the client's beat stream.
- **Controls:** ± BPM in steps of 1 (60–100), persisted in `@Shared(.tempoBPM)`. Metronome only (Q8).
- **Background audio:** keeps playing with the phone in a pocket.

**M6 — Drills**
- **Catalogue:** `DrillCatalogClient` loads the bundled `drills.json`. Category chips; save toggle writes `savedVideo`; the Saved chip uses `@FetchAll`.
- **Player:** `PlayerFeature` pushed on `AppPath` (`WKWebView` YouTube embed). "Start tempo" presents Tempo over the player.

**M7 — Scan (LiDAR)**
- **Gate:** live `GreenScanClient` gates on `supportsSceneReconstruction(.mesh)`; no LiDAR → S3 → "Use Quick Read" swaps the tool.
- **Scanning:**
  - S6 camera primer.
  - Mark ball and hole by raycast to anchors.
  - Scene-reconstruction mesh with coverage tracking along the ball→hole corridor: lime paint, % ring, gap prompts.
  - Poor-scan detection, and the bright-sun flag from light estimation.
- **Maths:** the height field becomes slope along the line, then aim (Q2), in Core.
- **Rendering:** the curved line in RealityKit (7pt lime), plus a dashed straight line, aim ring and the result card. Green speed sheet as `@Presents`.

**M8 — Polish and ship-readiness**
App icon (Icon A), launch screen, VoiceOver labels, Dynamic Type sanity, haptics audit, edge cases (permission denied, interruptions, phone calls during Tempo), App Store privacy strings (`NSCameraUsageDescription`, `NSMotionUsageDescription`), TestFlight checklist.

---

## 6. Testing

- **`GreenReadCore` (Swift Testing):**
  - aim maths: the README example plus 3 ft, 60 ft, 0% slope and downhill
  - unit formatting
  - slope sign conventions and `SlopeReader` stability
  - verdicts and points, every branch
  - tendency text, stats buckets and unlock
- **Features (Swift Testing + `TestStore`):**
  - Exhaustive tests per reducer, inheriting from `BaseSuite`: database bootstrapped, `\.uuid = .incrementing`, `\.continuousClock = TestClock()`.
  - Sensors come from scripted client values, so whole flows (lay flat → reading → result) run in milliseconds.
  - Failures use `expectNoDifference`; seed rows use negative `UUID(-n)` ids.
- **Previews:** every step and state, via the `.dependencies` preview trait with scripted clients and a seeded database.
- **On device (you):** a short field-test checklist per milestone. Sensors, AR and audio timing can only be verified on a real iPhone (a LiDAR model for Scan).

---

## 7. Environment and workflow

- **Local:** I now work on your Mac with Xcode 27. The Xcode MCP bridge (`xcrun mcpbridge`) is connected, so I build, run tests and read diagnostics myself, and you focus on device testing.
- **Core:** `GreenReadCore` and `GreenReadKit` tests also run with `swift test` / `xcodebuild test`.
- **Branches:** one branch + PR into `master` per milestone (Q12).

---

## 8. Risks

| Risk | Mitigation |
|---|---|
| Phone-flat slope accuracy (sensor bias, case on the back) | Average over a stable window; optional "calibrate on a flat surface" offset later (not in v1 unless you ask) |
| Scan is the largest and least certain piece (mesh noise on grass, sub-degree slopes) | Build it last; keep a straight-line/average-slope fallback; tune on a real green |
| Tempo timing drift | AVAudioEngine sample-time scheduling; UI follows the audio clock, not the store |
| Flooding the store with sensor data (60 Hz motion, AR frames) | Clients emit state changes and throttled values only (§2.3) |
| ARKit/RealityKit objects aren't `Sendable` and don't fit value-type state | They stay inside `GreenScanClient`; state holds only plain values (`GreenSurface`, anchors as `SIMD3<Float>`) |
| TCA learning curve and compile times | Feature-per-target modules so previews build only what they need |
| YouTube embed restrictions | `youtube-nocookie` embeds with `playsinline`; curate around creators who disable embedding |

---

## 9. Decisions

All 18 questions are decided (Q17–Q18 added in revision 4).

**Q1. "Plays like" distance ✅**
`playsLike = max(1, round(feet × (1 + uphill% × stimp / 100)))`, shorter when downhill (coaches' rule: extra feet per 10 ft = slope % × Stimp ÷ 10). At Medium: 15 ft at 1.2% uphill → 17 ft, matching the designs. Quick Read uses the Default green speed from Settings. Tune after field testing.

**Q2. Scan aim and green speed ✅**
Scan reads average uphill % and side % along the ball→hole corridor from the LiDAR mesh and applies the same Tour Read sum as Quick Read, then scales by `stimp / 10` (Slow ×0.8, Medium ×1.0, Fast ×1.2). Quick Read uses the same scaling, so Medium still gives 16in R. The curved line visualises that aim; no ball-roll simulation in v1.

**Q3. "Aimed" in Lay flat ✅ — option A**
Trust the golfer: "TOP EDGE → HOLE" is shown; once the phone is flat and held still for ~1 s, Flat ✓ and Aimed ✓ tick, the screen turns green and reads. Compass check possibly later.

**Q4. Train scoring ✅**
Round the measured slope to the nearest whole % (clamped 1–4) for the verdict and points; display the true decimal. Side slope under 0.5% = "Straight"; uphill under 0.5% = "Flat". Hill and aim are shown but not scored.

**Q5. Light mode only for v1 ✅**

**Q6. Drills ✅** Bundled `drills.json` with the six placeholder videos from the prototype for now. Real YouTube IDs come later.

**Q7. Save ✅** Saved on the device only (SQLiteData, `savedRead` table), with a "Saved" confirmation. No saved-reads screen in v1.

**Q8. Tempo ✅** Metronome only for MVP: pendulum, BACK/THROUGH labels, BPM 60–100 ± (default 76), Start/Stop, distinct sounds, haptics. Drill and Session are deferred.

**Q9. Permission primers ✅ — S6 and S7 as in design pack 3**
- **S6 camera:** "Let Scan see the green" / "The camera maps slope in 3D. Nothing is recorded or uploaded." / "Allow camera" · "Use Quick Read instead". First time Scan opens, then the system prompt. Quick Read's tap-to-measure goes straight to the system prompt; "Enter manually" always works.
- **S7 motion:** green card (220pt, radius 24) with phone lying flat and a lime triangle. "Let your phone feel the slope" / "Quick Read uses motion sensors to measure tilt when your phone lies flat. Only used during a read — nothing leaves your phone." / "Allow motion" (system prompt) · "Not now" (closes Quick Read back to Play). First Quick Read only.
- **Denied later:** Quick Read opens on the same screen with primary "Open Settings" and body "Motion access is off. Turn it on in Settings to use Quick Read."
- **Info.plist:** `NSCameraUsageDescription` "GreenRead uses the camera to map the green and show your putting line."; `NSMotionUsageDescription` "GreenRead measures the slope of the green when your phone lies flat."
- Technical note: tilt readings need no iOS permission; "Allow motion" uses the Motion & Fitness authorisation (also used by Walk it off), and its status drives the denied state.

**Q10. Pace length and Stimp ✅** Simple ± steppers: pace 2.0–3.5 ft (default 2.7), Stimp 6–14.

**Q11. Stats trend chart ✅ — yes**
Accuracy = average round score over recent rounds (the figure on the Home Stats tile). Swift Charts line of the last 7 rounds, styled like 9b, under the 9a insight card.

**Q12. Repo and workflow ✅**
Bundle ID `com.garethlloyd.greenread`; no Mac CI build; one branch + PR per milestone; the `.xcodeproj` is committed so it opens directly in Xcode (requires Xcode 16+).

**Q13. Units ✅** Feet by default, metres in Settings.

**Q14. Sounds toggle ✅** Settings has both Sounds and Haptics switches (as in the design pack), so the metronome can run on vibration only.

**Q15. High-contrast mode (S5) ✅** In strong sun, Scan overlays get heavier (thicker break line, larger markers) and the result card is fully opaque. Nothing else changes.

**Q16. Stats insight wording ✅** Templated on the two designed examples: "You under-read / over-read {group} putts by about {n}%" for the group furthest off, "Your {group} reads are improving" when a group's error shrinks over recent rounds, and "Your reads are well balanced" when everything is close.

**Interpretation noted during M0:** Read mode uses the side slope rounded to the nearest whole % in the Tour Read sum (as design 5a does: 2.1% shown, "× 2% slope" in the working), with the true decimal shown on the card.

**Q17. Tempo when the sheet closes ✅**
Closing the Tempo sheet stops the metronome. Stop lives on the sheet, and background audio still covers the phone going into a pocket with the sheet open. `TempoClient`'s effect is tied to `TempoFeature`, so dismissing it cancels playback.

**Q18. Persistence swap ✅**
SwiftData is replaced: SQLiteData for records and `@Shared` for settings (§2.4). Nothing has shipped, so there's no migration.

---

## 10. Out of scope for v1 (unless you say otherwise)

iPad, landscape, Apple Watch, Tempo backswing drill and practice session (10/11, T1, 11d), dark mode, accounts/cloud sync, sharing a scorecard (8d), drill recommendations from stats (8c/12c), the "Drill of the week" hero, ball-roll physics simulation, localisation beyond English (UK spelling as in the handoff: "colour", "practise").

---

**Status:** M0–M1 merged; M1.5–M8 in review as stacked PRs #3–#10. Release checklist: [`docs/RELEASE.md`](RELEASE.md).
