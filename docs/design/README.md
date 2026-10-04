# Handoff: GreenRead — Find the line (iOS)

## Overview
**App name: GreenRead. Tagline: "Find the line."**

App name: **GreenRead**. Tagline: **"Find the line."** Wordmark = Archivo 800, width 118%, letter-spacing −0.03em; "Green" in Ink #0E1411, "Read" in Green #1E9E5A (on dark: white + Line lime #D4F53C). Tagline in JetBrains Mono 600 uppercase, tracking 0.1em. Recommended icon: Icon A (cup & line) in Components & Brand.

A native iOS putting assistant for golfers. Four tools — **Scan** (AR green read, LiDAR), **Quick Read** (phone laid flat on the green; Read + Train modes), **Tempo** (metronome / backswing drill) — plus a **Drills & Tips** video library and **Stats**. For practice and casual play only (slope devices are not permitted in competition under the Rules of Golf — this disclaimer must appear in Settings).

## About the design files
Everything in this bundle is a **design reference built in HTML** — prototypes showing intended look and behaviour, not production code. Recreate them natively in **SwiftUI** (iOS 17+), using ARKit/RealityKit for Scan and CoreMotion for Quick Read. Do not ship or wrap the HTML.

- `prototype/Putting App Prototype.dc.html` — **the source of truth.** Clickable, open in a browser. The logic class at the bottom of the file shows exact state, flow and the aim maths.
- `reference/Navigation v2.dc.html` — navigation options; **option Nd** was chosen (top segmented switch, no tab bar).
- `reference/Putting App Design Pack.html` — every screen with 4–5 explored options + states, component sheet, palette. Use for screens the prototype only covers lightly (Stats, Drills, Tempo drill/session, onboarding, edge states).
- `reference/Flow Diagram.dc.html` — full flow map.
- `reference/original-brief.md`, `reference/tour-read-method.jpeg` — original brief and the aim method.

## Fidelity
**High-fidelity** for colours, type, radii, layout and flow. Camera/AR imagery is placeholder (striped green) — replace with the live camera feed. Icons are placeholder glyphs — use SF Symbols.

## Brand
- Wordmark: "GreenRead" set in Archivo 800, width 118%, letter-spacing −0.03em. "Green" in Ink `#0E1411`, "Read" in Green `#1E9E5A`. On dark: "Green" white, "Read" Line lime `#D4F53C`.
- Tagline: "FIND THE LINE" — JetBrains Mono 600, uppercase, letter-spacing 0.1–0.12em, `#5B635D` (on dark `#C5CAC2`).
- App icon: Icon A (cup & line) — green `#1E9E5A` rounded square, black cup ellipse top, white ball bottom-left, lime break line between. Provide all iOS sizes. Concepts in `reference/Components & Brand.dc.html`.
- Bundle display name: "GreenRead". Use the wordmark on Home and onboarding; never as an image — render as text.

## Navigation (final)
- Home header: GreenRead wordmark (30pt) with "FIND THE LINE" tagline beneath, 20pt side padding.
- **No bottom tab bar.** Home has a top **segmented control: Play | Drills** (46pt tall, pill) with a **⚙ Settings** circle button to its right.
- Above the switch: GreenRead wordmark (30pt) + "FIND THE LINE" tagline.
- **Play** = vertical list of large tiles: Scan (green, hero), Quick Read, Tempo, Stats.
- **Scan and Quick Read open as full-screen modals** (`.fullScreenCover`, slide up 0.32s ease-out). Modal chrome: ✕ close button top-left (48pt circle, white), centred tool-name pill that opens a switcher (Scan ↔ Quick Read). Quick Read additionally shows a **Read | Train** segmented control under the chrome.
- **Tempo** and **Settings** are bottom sheets (`.sheet` with detents), dismiss by drag or backdrop tap.
- **Stats** and **video player** push full-screen with a ‹ back button.

## Onboarding
Use design-pack option **1b** (single-page tour): wordmark (22pt) + headline "Four tools. Find the line." + four tool rows + "Get started". Ask permissions in context the first time Scan (camera) or Quick Read (motion) opens — primer screen S6 then system prompt.

## Permission screens

### Motion permission primer (S7 — shown before the system prompt, first Quick Read only)
- Visual: green card (220pt tall, radius 24) with a phone shown lying flat, lime triangle on screen.
- Title: **Let your phone feel the slope**
- Body: **Quick Read uses motion sensors to measure tilt when your phone lies flat. Only used during a read — nothing leaves your phone.**
- Primary: **Allow motion** → triggers the system prompt. Secondary text button: **Not now** → closes the Quick Read modal back to Play.
- If denied later: on opening Quick Read show the same screen with primary **Open Settings** and body "Motion access is off. Turn it on in Settings to use Quick Read."
- Info.plist `NSMotionUsageDescription`: "GreenRead measures the slope of the green when your phone lies flat."
- Camera primer (S6) Info.plist `NSCameraUsageDescription`: "GreenRead uses the camera to map the green and show your putting line."

## Screens & flows
### Scan (modal)
1. **Mark** — live camera; tap ball, then hole (markers pop in). Bottom: Undo + "Start scan" (lime, enabled once both placed).
2. **Scanning** — lime coverage overlay grows; top-right progress ring (78pt, conic lime fill, % in centre); one large prompt pill bottom ("Walk slowly to the hole" / "Slow down" / "Cover left side" / "Gap behind you"). Auto-advances at 100%.
3. **Green speed** — bottom sheet: Slow / Medium / Fast (Stimp 8/10/12) → "Show my line".
4. **Result** — curved lime break line (7pt), dashed white straight line, aim ring + "AIM x L" label; bottom card with ACTUAL / PLAYS (▲ uphill) / AIM (green), Rescan + Save.
- Edge states (design pack): no LiDAR → route to Quick Read; poor scan → "Rescan gaps only"; bright-sun banner; camera permission primer.

### Quick Read — Read mode (modal)
1. **Measure** — camera, tap ball then hole → distance chip + card. Alternatives: "Enter manually" (± stepper), "Walk it off" (pedometer, calibrated pace).
2. **Lay flat** — full-screen colour state: **orange** until flat+aimed, **green** when good. Big white triangle + "TOP EDGE → HOLE", Flat ✓ / Aimed rows, then live UPHILL % and SIDE % chips, "Reading…" then auto-advance. (Prototype times this; build from CoreMotion attitude with a stability threshold.)
3. **Result card** — AIM (56pt, green, e.g. "16in R"), ACTUAL / PLAYS / SLOPE; collapsible **"How we got this"** panel showing the working; New read / Save.

### Quick Read — Train mode (modal)
Round of 5 putts: **Measure → Guess → Lay flat (numbers hidden, "no peeking") → Reveal** ×5 → **Round summary**.
- Guess: chips for Slope 1–4%, Break L→R / R→L / Straight, Hill Up/Flat/Down, Aim stepper. "Lock in & lay phone" enabled when slope, break, hill chosen.
- Reveal: verdict banner (Spot on = green, Under-read/Wrong way = clay, Over-read = slate), You vs Actual columns.
- Summary: score /100 (20/12/5 pts by slope error, −5 for wrong break), per-putt verdict list, tendency sentence, Stats / Play again.
- Stats: locked until 3 rounds (empty state with progress bars), then insight card + diverging under/over bars by direction, hill, slope band, distance band.

### Tempo (sheet)
Pendulum (swings on each beat; BACK / THROUGH labels light up), BPM 60–100 (default 76) with ± buttons, Start/Stop (96pt circle). Distinct back/through sounds + haptics. Full version (design pack 10/11): backswing drill 10/20/30 ft, practice session with random distances.

### Drills tab
Horizontal category chips (All, Saved, Green reading, Speed control, Tempo, Alignment, Short putts); list rows with thumbnail (duration badge), title, creator · category, ♥ save toggle. Player: YouTube embed, Save, "Start tempo" (opens Tempo sheet over the player).

### Settings (sheet)
Units ft/m · **Aim unit Inches / Cups / Balls** (segmented; changes every aim number across Scan, Quick Read, Train guess/reveal and the "How we got this" working) · Default green speed · Pace length · Haptics toggle · Rules-of-Golf disclaimer (clay tint box).

## Aim maths (Tour Read method)
```
yards   = feet / 3
base    = round(yards * 2 - 1)        // inches of break at 1% slope, min 1
aim     = base * slopePercent
uphill  : aim -= slopePercent         // downhill: += slopePercent
```
Example: 15 ft, 2% R→L, uphill → 9in × 2 = 18 − 2 = **16in right**.
Unit conversion for display only (store inches): cup = 4.25in (round to 0.5), ball = 1.68in (round to integer). Distance m = ft × 0.3048.

## Design tokens
Colours
- Ink `#0E1411` — text, primary neutral buttons, dark cards
- Chalk `#F5F6F2` — app background; cards `#FFFFFF`
- Green `#1E9E5A` — go / aim / spot on / selected tab
- Line lime `#D4F53C` — AR overlays & highlights on dark only
- Clay `#D9622B` — under-read / warnings; tint `#FBE7DD`, text on tint `#6B2C10`
- Slate `#4A6FA5` — over-read
- Secondary text `#5B635D`; muted `#8A918B`; borders `#DADDD5`; fills `#EEF0EA`, `#E3E6DE`

Type
- **Archivo** (variable, width 62–125). Numbers/headlines: weight 800, width 110–120%, letter-spacing −0.02 to −0.05em. Body 400–600.
- **JetBrains Mono** 600, 10–13pt, letter-spacing 0.08em, UPPERCASE — small labels (ACTUAL, PLAYS, AIM).
- Scale used (pt): 10, 11, 12, 13, 14, 15, 16, 17, 19, 22, 24, 26, 30, 34, 56, 60, 72.

Shape & spacing
- Radii: chips 12–14, cards 20–26, bottom cards/sheets 30–32 top, buttons fully pill.
- Buttons: primary 56–58pt tall; circular actions 48–96pt. **Minimum tap target 48pt.**
- Screen padding 16–18pt; card padding 16–20pt; gaps 8–12pt.
- Shadow (floating controls on camera): `0 2 8 rgba(14,20,17,.15)`; popovers `0 14 34 rgba(14,20,17,.35)`.

Motion
- Modal slide-up 0.32s ease-out; sheet 0.3s; fade 0.2–0.3s; result numbers "pop" (scale 0.6 → 1.06 → 1, 0.4s); flat-screen background colour transition 0.4s; pendulum 0.35s ease-in-out per beat.

## State (from prototype)
`tab (play|drills)`, `modal (scan|qr|nil)`, `step`, `mode (read|train)`, `units`, `aimUnit`, `haptics`, `bpm`, `isPlaying`, `greenSpeed`, `distance`, `puttIndex`, `guess {slope, dir, hill, aim}`, `results[]`, `roundsPlayed`, `savedVideoIds`, `drillCategory`. Persist settings, saved videos, rounds/results (SwiftData).

## Assets
None final. Need: app icon (3 concepts in design pack), drill thumbnails (YouTube), SF Symbols for UI icons. No emoji in production UI.
