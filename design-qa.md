# Cove native redesign QA

- Source visual truth:
  - `C:\Users\victo\AppData\Local\Temp\codex-clipboard-dfd0782a-7730-4259-852c-b57c21c9da36.png` — 1180 × 2676 px.
  - `C:\Users\victo\AppData\Local\Temp\codex-clipboard-c7328d3a-09b7-4f63-885f-f04f2129db73.png` — 1170 × 2532 px.
  - `C:\Users\victo\AppData\Local\Temp\codex-clipboard-02d471f9-d300-465a-8d10-b277d3a7ce12.png` — 1170 × 2532 px.
  - `C:\Users\victo\AppData\Local\Temp\codex-clipboard-7250352b-5f88-41a2-9645-29fc08b8433a.png` — 1170 × 2532 px.
- Intended comparison: shared principles and quality bar only. The user explicitly prohibited exact layout, color, illustration, icon, type, dimension, branding, and asset reproduction.
- Implementation screenshot: unavailable.
- Target native viewports: 320 × 568 pt, 393 × 852 pt, and 430 × 932 pt; light mode, default text size, plus Dynamic Type accessibility sizes.
- Density normalization: blocked because no native implementation capture is available.
- State coverage requested: Welcome, all Planner steps, Generation, Week, Recipe, Groceries, Already Have, Swap, Cove Pro, and relaunch.

## Full-view comparison evidence

All four references were opened and inspected. The implementation could not be rendered on this Windows host because Xcode, SwiftUI, and the iOS Simulator are unavailable. A source-to-implementation composite therefore cannot be produced locally.

## Focused-region comparison evidence

Blocked for the same reason. The first macOS QA pass should capture Welcome, Food preferences, Week, a grocery department with mixed states, Recipe nutrition/instructions, Swap, and Cove Pro at 393 × 852 pt.

## Findings

- [P1] Native visual output is not yet captured.
  - Evidence: the SwiftUI source is present, but this host cannot run the native app.
  - Impact: image crops, safe-area spacing, toolbar density, sheet height, Dynamic Type wrapping, and compact-width behavior cannot be approved from source alone.
  - Fix: run the existing macOS Xcode workflow, capture the required screens on at least 320, 393, and 430 point widths, and compare them alongside the references.

## Required fidelity surfaces

- Fonts and typography: designed around compact dynamic system sans-serif styles with rounded display moments; render verification blocked.
- Spacing and layout rhythm: shared Cove tokens and safe-area CTAs are implemented; render verification blocked.
- Colors and visual tokens: original adaptive ivory, espresso, forest, sage, terracotta, gold, and muted teal palette is implemented; contrast must be checked in rendered light and dark modes.
- Image quality and asset fidelity: existing full-resolution Cove food photographs are used throughout; crop and focal-point verification is blocked.
- Copy and content: Cove naming, tagline, planner questions, weekly summary, grocery states, swap repricing, and Cove Pro language are implemented and source-audited.

## Comparison history

- Pass 1: source references inspected; implementation capture blocked before visual comparison.

## Implementation checklist

1. Compile and run Swift unit/UI tests on macOS.
2. Capture the complete flow at 393 × 852 pt.
3. Repeat compact-width, large-width, Dynamic Type, and dark-mode captures.
4. Fix any P0/P1/P2 visual findings and rerun the comparison.

final result: blocked
