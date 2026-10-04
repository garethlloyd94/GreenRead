# GreenRead — Build Plan (for approval)

**App:** GreenRead — "Find the line."
**Platform:** Native iOS, SwiftUI, iOS 17+, iPhone only (portrait).
**Frameworks:** SwiftUI · SwiftData · CoreMotion · ARKit/RealityKit · AVAudioEngine · Core Haptics · WebKit (YouTube player only).
**Source of truth:** `design_handoff_putting_app/` — README spec, then `prototype/Putting App Prototype.dc.html`, then `reference/Putting App Design Pack.html` for screens the prototype covers lightly.

Status: **REVISION 3 — all decisions made.** Designs: design pack 3 (`User_flow_and_screen_options_3.zip`). Visual version with every screen: https://claude.ai/artifact/2qBkK3YWoEtsbH4pab11FR

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

Onboarding follows option **1b**: a single-page tour ("Four tools. Find the line."). Camera and motion permissions are asked in context the first time Scan or Quick Read opens, using the primer screen S6 before the system prompt.

---

## 2. Architecture

```
GreenRead/                         ← repo root
├─ GreenRead.xcodeproj            ← hand-written; GreenRead/ is a folder-synchronised group
├─ GreenRead/                      ← app target
│  ├─ App/                         GreenReadApp, RootView, AppState (router)
│  ├─ DesignSystem/                Tokens (Color/Font/Radius/Shadow/Motion), components
│  ├─ Features/
│  │  ├─ Home/                     Header, Play tiles, Play|Drills switch
│  │  ├─ Onboarding/               1b tour, permission primers
│  │  ├─ QuickRead/                Measure, LayFlat, Result, Train (Guess/Reveal/Summary)
│  │  ├─ Scan/                     Mark, Scanning, GreenSpeed, Result, edge states
│  │  ├─ Stats/
│  │  ├─ Tempo/                    Metronome, Drill, Session
│  │  ├─ Drills/                   Feed, Player (WKWebView)
│  │  └─ Settings/
│  ├─ Services/                    MotionService, TempoEngine, Haptics, PedometerService,
│  │                               ARMeasureService, GreenScanService, PermissionService
│  ├─ Persistence/                 SwiftData models + ModelContainer
│  └─ Resources/                   Fonts (Archivo, JetBrains Mono), Assets (icon), drills.json, sounds
├─ Packages/GreenReadCore/         ← pure Swift package, no UIKit/ARKit
│  ├─ AimCalculator                Tour Read maths + unit formatting
│  ├─ SlopeReader                  attitude → uphill % / side % / break / hill + stability
│  ├─ TrainScoring                 verdicts, points, tendency sentence
│  ├─ StatsEngine                  breakdown buckets, insight, 3-round unlock
│  └─ Tests/                       XCTest (includes README example 15 ft, 2% R→L, uphill → 16in R)
└─ docs/                           this plan, design handoff copy
```

- **State:** the `@Observable` pattern (iOS 17) with one `AppState` (tab, active modal, sheets, navigation path) and a view model per feature. Each feature's step machine mirrors the prototype's `step` values (`measure → guess → flat → tr-reveal → tr-summary`, `scan-mark → scan-scan → scan-speed → scan-result`).
- **Pure logic lives in `GreenReadCore`.** It has no Apple UI dependencies, so it is unit-testable and can be built and tested from Linux with the Swift toolchain. That means I can prove the maths and scoring here, even though this environment can't build the iOS app.
- **Persistence (SwiftData):** `UserSettings`, `SavedVideo`, `TrainRound` → `TrainPutt[]`, `SavedRead` (Quick Read or Scan result). Settings could use `@AppStorage`; I'll use SwiftData for everything except the onboarding-seen flag.
- **No backend, no account, no analytics.** Fully offline except YouTube playback. The S6 copy promises "Nothing is recorded or uploaded."
- **Fonts:** Archivo (variable, with a width axis) and JetBrains Mono, both under the OFL licence and bundled. Archivo's width (110–120%) is applied through `UIFontDescriptor` variation axes, wrapped in a `Font.archivo(size:weight:width:)` helper.
- **Project file:** a small hand-written `.xcodeproj` using Xcode 16 folder-synchronised groups, so every file under `GreenRead/` is included automatically and the project file rarely changes. (XcodeGen was the original plan, but it can't be installed in the cloud environment; this needs no extra tools on your Mac either.)

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
- "Aimed": CoreMotion can't know where the hole is. The plan is to take the heading of the phone's top edge and compare it with the ball→hole bearing captured by the AR measure step. When the distance was entered manually or walked off, there's no bearing, so "Aimed" means "the user has held it still" (see Q3).

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

**M0 — Project skeleton**
Xcode project (folder-synchronised), app target and local `GreenReadCore` package (Tour Read maths, units and formatting pulled forward from M3 so the tests exist from day one), SwiftData container, bundled fonts, copy of the design handoff in `docs/design/`, CI-free `swift test` for Core, `.gitignore`, README describing how to build.

**M1 — Design system**
Colour/type/radius/shadow/motion tokens; `GreenReadWordmark` (text, not an image); components: `PillButton` (go, neutral, secondary), `Chip`, `PillSegmentedControl`, `ResultCard`, `BottomCard`, `CircleIconButton`, `MonoLabel`, `VerdictBanner`, `DivergingBar`, `VideoRow`. Includes a DEBUG-only component gallery screen for checking against the design pack.

**M2 — Home + Settings + Onboarding**
Play | Drills switch, tiles (the Tempo subtitle shows live BPM; the Stats tile shows "x/3 rounds" or the accuracy figure), Settings sheet with all controls and the Rules of Golf box, onboarding 1b, and an `AimFormatter` environment value so changing the aim unit updates every screen.

**M3 — Quick Read: Read**
`AimCalculator` + tests; `MotionService` (CMMotionManager, 60 Hz, stability filter); measure options (AR raycast tap via ARKit, any iPhone; pedometer walk-off with pace length; manual stepper); lay-flat state screen; result card with the pop animation and working panel; Save → `SavedRead`.

**M4 — Quick Read: Train + Stats**
Guess form, hidden lay-flat, reveal, summary, `TrainScoring` + `StatsEngine` + tests, SwiftData rounds, Stats locked/unlocked, Play again, Stats from summary.

**M5 — Tempo**
`TempoEngine` on AVAudioEngine with sample-accurate scheduling (buffers scheduled ahead against `AVAudioTime`, not timers), distinct back and through sounds, Core Haptics synced to the beat, pendulum driven by the audio clock, ± BPM in steps of 1 (60–100). Metronome only for MVP; Drill and Session are deferred (Q8). Background audio, so it keeps playing with the phone in a pocket.

**M6 — Drills**
`drills.json` catalogue, category chips (All, Saved, Green reading, Speed control, Tempo, Alignment, Short putts), save toggle (SwiftData), player screen with a `WKWebView` YouTube embed, "Start tempo" opening the Tempo sheet over the player.

**M7 — Scan (LiDAR)**
Device gate on `ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)` (no LiDAR → S3 → Quick Read). Mark ball and hole by raycast to anchors, scene-reconstruction mesh, coverage tracking along a ball→hole corridor (lime paint overlay, % ring, gap prompts), poor-scan detection, a bright-sun banner from ARKit light estimation, a height field sampled from the mesh, slope along the line, aim (see Q2), a curved line rendered in RealityKit (7pt lime) plus a dashed straight line and aim ring, and the result card.

**M8 — Polish and ship-readiness**
App icon (Icon A, all sizes), launch screen, VoiceOver labels, Dynamic Type sanity, haptics audit, edge cases (permission denied, interruptions, phone calls during Tempo), App Store privacy strings (`NSCameraUsageDescription`, `NSMotionUsageDescription`), TestFlight checklist.

---

## 6. Testing

- **`GreenReadCore` (XCTest):** aim maths (README example plus edge cases: 3 ft, 60 ft, 0% slope, downhill), unit formatting (cups rounded to 0.5, balls to integers, metres), slope sign conventions, verdicts and points (every branch from the prototype), tendency text, stats buckets and unlock.
- **App:** view-model unit tests with a mock `MotionService` (feeding scripted attitude) and an in-memory SwiftData store, plus SwiftUI previews for every state.
- **On device (you):** a short field-test checklist per milestone. Sensors, AR and audio timing can only be verified on a real iPhone (a LiDAR model for Scan).

---

## 7. Environment and workflow

- I write the code here (cloud Linux). **I can't build or run the iOS app in this environment.** You build and run it in Xcode 15+ on a Mac and report back any compiler errors or behaviour issues.
- To shorten that loop: (a) all maths and logic sit in `GreenReadCore`, which I can compile and test here if I install the Swift Linux toolchain; (b) optionally, a GitHub Actions workflow on a `macos` runner that runs `xcodebuild build test` on every push, so I can see compile errors myself (see Q12).
- Branch per milestone, with a PR into `main` if you want reviews (see Q12).

---

## 8. Risks

| Risk | Mitigation |
|---|---|
| Phone-flat slope accuracy (sensor bias, case on the back) | Average over a stable window; optional "calibrate on a flat surface" offset later (not in the designs, so not in v1 unless you ask) |
| "Aimed" detection without a known hole direction | Use the AR-measured bearing when available (Q3) |
| Scan is the largest and least certain piece (mesh noise on grass, sub-degree slopes) | Build it last; keep a straight-line/average-slope fallback; tune on a real green |
| Tempo timing drift | AVAudioEngine sample-time scheduling; UI follows the audio clock |
| YouTube embed restrictions | Use `youtube-nocookie` embeds with `playsinline`; some creators disable embedding, so curate around that |
| No Mac in this environment | Logic package tested here; optional macOS CI |

---

## 9. Decisions

All 13 questions are decided.

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

**Q7. Save ✅** Saved on the device only (SwiftData), with a "Saved" confirmation. No saved-reads screen in v1.

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

---

## 10. Out of scope for v1 (unless you say otherwise)

iPad, landscape, Apple Watch, Tempo backswing drill and practice session (10/11, T1, 11d), dark mode, accounts/cloud sync, sharing a scorecard (8d), drill recommendations from stats (8c/12c), the "Drill of the week" hero, ball-roll physics simulation, localisation beyond English (UK spelling as in the handoff: "colour", "practise").

---

**Status:** M0 + M1 in progress on branch `m0-m1-foundation`.
