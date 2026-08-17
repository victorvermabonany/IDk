# Cove for iOS

Cove is a native SwiftUI iPhone client. The Xcode project, target, module, directory names, and bundle identifiers intentionally remain `Weektable`/`com.weektable.ios` during the beta to avoid breaking CI, persistence, Appetize history, StoreKit preparation, or future signing. The installed display name and visible product copy are Cove.

## Run

Requirements: Xcode 16+, iOS 17+, and XcodeGen.

```bash
cd ios
xcodegen generate
open Weektable.xcodeproj
```

## Runtime modes

- `DEVELOPMENT_FIXTURE`: Debug previews and deterministic tests; may use `DemoPlanRepository`.
- `STAGING_LIVE`: Debug/Appetize using an HTTPS `COVE_API_BASE_URL`.
- `PRODUCTION_LIVE`: Release/TestFlight; requires live API and legal URLs and never falls back to demo data.

Live builds require `COVE_API_BASE_URL`, `COVE_PRIVACY_URL`, `COVE_TERMS_URL`, and `COVE_SUPPORT_URL`. Deprecated `WEEKTABLE_*` URL keys are temporarily read for compatibility. OpenAI, PostgreSQL, and Kroger credentials remain server-side.

GitHub Actions generates the project, validates Release configuration, runs Swift unit/UI tests, and builds the ARM simulator archive. The shared contract filename `../shared/openapi/weektable-v1.yaml` is also retained for compatibility.
