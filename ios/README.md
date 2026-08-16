# Weektable for iOS

A native SwiftUI implementation of the Weektable V1 planning flow. The existing Next.js app remains the behavioral reference; this project is a separate iPhone client.

## Requirements

- macOS with Xcode 16+
- iOS 17+
- XcodeGen (`brew install xcodegen`)

## Open and run

```bash
cd ios
xcodegen generate
open Weektable.xcodeproj
```

Choose an iPhone simulator and run the `Weektable` scheme.

## Build for Appetize from Windows

The repository root includes `codemagic.yaml` and a GitHub Actions workflow.
Either cloud build produces `Weektable-Appetize.zip`, an unsigned ARM iOS
Simulator build that can be uploaded directly to Appetize. See
`../APPETIZE_BUILD.md` for the complete Windows instructions.

The default configuration uses `DemoPlanRepository`, which provides the deterministic fixture plan without network access. To connect the shared backend, construct `AppModel` with `APIPlanRepository`, a versioned base URL, and the anonymous-session credential provider. OpenAI and grocery-provider credentials remain server-side.

The shared V1 contract lives at `../shared/openapi/weektable-v1.yaml` and is ready to become the input to Apple Swift OpenAPI Generator once the TypeScript server exposes the versioned routes.

## Architecture

- SwiftUI with typed native navigation and sheets
- Observation-based feature state
- `URLSession` API client and repository boundary
- SwiftData persistence for planner drafts, cached plan snapshots, and grocery state
- Resumable generation jobs
- Server-authoritative pricing, package math, constraints, and swap repricing
- Dynamic Type, VoiceOver labels, Reduce Motion support, safe-area CTAs, light/dark semantic colors, and haptics

## Validation on macOS

```bash
xcodegen generate
xcodebuild -project Weektable.xcodeproj -scheme Weektable \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

Also run the UI test plan on a compact iPhone SE-size simulator and a large Pro Max simulator, in light/dark appearances and accessibility text sizes.

On macOS, `Scripts/validate-ios.sh` generates the project, runs the unit/UI tests on iPhone 16 Pro, and builds the compact and Pro Max destinations. Follow `QA.md` for the visual, keyboard, Dynamic Type, dark-mode, safe-area, and VoiceOver pass.
