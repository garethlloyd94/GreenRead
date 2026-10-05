Build GreenRead ("Find the line"), a native iOS app (SwiftUI, iOS 17+, ARKit + CoreMotion, SwiftData) from the design handoff in this folder.

1. Read `README.md` fully first — it is the spec (navigation, screens, flows, aim maths, design tokens).
2. Open `prototype/Putting App Prototype.dc.html` in a browser and click through it; it is the source of truth for layout, copy and behaviour. The logic class at the bottom of that file shows state transitions and the aim calculation.
3. Use `reference/Putting App Design Pack.html` for screens the prototype covers lightly (Stats, Drills, Tempo drill/session, onboarding, edge states). Where a screen shows several options, use the one closest to the prototype.

The HTML is a design reference only — recreate it natively; do not embed web views (except the YouTube player).

Build order:
1. Design tokens (colours, Archivo + JetBrains Mono fonts, radii) and shared components (pill buttons, chips, segmented control, result card, bottom card).
2. Home with Play | Drills top switch + Settings sheet (incl. Aim unit: inches/cups/balls).
3. Quick Read Read mode (CoreMotion flat/aim detection → slope → aim maths) as a full-screen modal.
4. Quick Read Train mode (5-putt loop, scoring, summary, Stats with 3-round unlock).
5. Tempo sheet (accurate audio timing with AVAudioEngine, distinct back/through sounds, haptics).
6. Drills feed + player + saved.
7. Scan (ARKit scene reconstruction, LiDAR only; mark ball/hole, coverage, green speed, curved line). Show the non-LiDAR fallback to Quick Read.

Unit-test the aim maths with the README example (15 ft, 2% R→L, uphill → 16in right). Ask me before inventing any screen or copy not in the files.
