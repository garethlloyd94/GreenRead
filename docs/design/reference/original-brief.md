# Putting App – Design Brief

Design a native iOS putting-assistant app for golfers. It's used outdoors on the putting green, often one-handed and in bright sunlight, so prioritise high contrast, large tap targets, minimal text, and glanceable results. Clean, modern, premium sports-tech feel. Support light and dark mode. Distances default to feet, with a ft/m toggle in settings.

The app has a bottom tab bar with four tabs.

---

## 1. SCAN (AR green read)

Uses the iPhone LiDAR camera to map the green and show the putt line in AR.

**Flow and screens**

- **Mark ball & hole:** live camera view; the user taps the ball, then the hole, and each gets a 3D pin/marker.
- **Scan:** the user walks slowly from ball to hole pointing the phone at the green. Show a coverage overlay "painting" the scanned area, a progress indicator, and gentle prompts ("Slow down", "Cover left side", "Gap behind you").
- **Green speed:** quick picker (Slow / Medium / Fast, or a Stimp number).
- **Result (AR):** a curved line drawn on the real green from ball to hole, with an aim-point marker. Result card shows:
  - Actual distance (e.g. 10 ft)
  - Plays like (e.g. 12 ft – uphill)
  - Aim (e.g. "2 cups left" / "Left edge")
  - Uphill/downhill and break direction icons
- **States:** non-LiDAR device (explain it and point to tab 2), poor scan / rescan, bright-sun warning, camera permission request.

---

## 2. QUICK READ (phone on the ground)

The user measures the putt distance, lays the phone flat on the green pointing directly at the hole, and the app reads the slope and gives the aim. Two modes, switchable via a segmented control at the top: **"Read"** (normal) and **"Train"** (game).

### Read mode

- **Step 1, Measure distance:** default AR point-and-tap (tap ball, tap hole through the camera), with secondary options "Walk it off" (tap at ball, walk to hole, tap) and "Enter manually" (paces or feet stepper). Show the measured distance large, with an edit button.
- **Step 2, Lay phone flat:** illustration of placing the phone, top edge aimed at the hole, with a live level indicator that turns green when it's flat and aimed.
- **Live reading:** uphill/downhill angle and left/right side slope, shown visually (e.g. bubble level or tilted-green graphic).
- **Result card:** actual distance, "plays like" distance, slope %, break direction, and aim point.
- Option to save the read or start a new one.

### Aim calculation (both modes)

Uses the Tour Read method (reference screenshot attached):

- 1% break number = (distance in yards × 2) − 1
- Scaled by measured slope (2%, 3%, 4%), with uphill/downhill adjustment.
- Show the working on the result card in a simple, collapsible "How we got this" panel.
- The unit for the aim number (e.g. cups or ball widths) is to be confirmed; design the display so the unit label is easy to change.

### Train mode – "Read the Green" game

- A round is 5 putts from 5 different positions. Show a round progress indicator (e.g. 5 dots).
- For each putt:
  1. **Measure distance** (same options as Read mode).
  2. **Guess screen:** user enters their read BEFORE the phone measures slope: slope estimate (1% / 2% / 3% / 4% chips), break direction (left-to-right / right-to-left / straight), uphill / downhill / flat, and aim point (e.g. cups or ball widths, left/right).
  3. **Lay phone flat:** in this mode, hide all live slope numbers; show only an "is it flat and aimed" indicator.
  4. **Reveal:** a satisfying animated reveal comparing guess vs actual side by side, with a clear verdict: "Over-read", "Under-read" or "Spot on", plus how far off (e.g. "You read 2%, it was 3%").
- **Round summary** after 5 putts: score, accuracy for each putt, and the biggest tendency from the round.

### Progress (inside Train mode, or a "Stats" button)

Data builds over time across rounds. Design:

- Headline insight card in plain language, e.g. "You under-read left-to-right putts by about 30%" or "Your downhill reads are improving".
- Breakdown by break direction (L-to-R vs R-to-L), uphill vs downhill, slope band (1–4%) and distance band (under 10 ft / 10–20 ft / 20 ft+), each showing an over-read/under-read tendency.
- Trend chart of accuracy over recent rounds.
- Round history list.
- Empty state for new users ("Play 3 rounds to unlock your insights").

---

## 3. TEMPO

A putting metronome plus a backswing-length drill for 10, 20 and 30 ft.

- **Metronome:** big start/stop button, BPM control (dial or stepper), distinct "back" and "through" beat sounds, visual pulse/pendulum, haptic option.
- **Backswing drill:** concept is constant tempo, with backswing length changing with distance. Distance selector (10 / 20 / 30 ft) with a simple diagram showing backswing length for each (e.g. relative to feet or a putter-head graphic).
- **Practice session mode:** choose distance(s), number of reps, running rep counter, and an optional "random distance" mode.

---

## 4. DRILLS & TIPS

Curated YouTube videos on putting.

- Category chips (Green reading, Speed control, Tempo, Alignment, Short putts).
- Video cards with thumbnail, title, duration and creator; in-app player.
- Save/favourite, plus a "Saved" filter.
- Optional "Featured drill of the week" hero card.

---

## Also include

- Short onboarding (3 screens max) explaining the four tabs and requesting camera/motion permissions in context.
- **Settings:** units, default green speed, pace length calibration, sounds/haptics, and a note that slope-reading devices aren't allowed during competitive rounds under the Rules of Golf (practice and casual play only).
- App icon and colour palette suggestions.

## Deliverables

High-fidelity mockups of every screen and state listed above, the main flow for each tab, and a small component sheet (buttons, result card, tab bar, chips, video card, guess/reveal card, insight card).
