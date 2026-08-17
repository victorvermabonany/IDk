# Cove on BrowserStack App Live

The iOS CI pipeline produces two independent artifacts:

- `Cove-Appetize.zip`: ARM iOS Simulator app for Appetize.
- `Cove-BrowserStack.ipa`: ARM64 physical-iPhone app for BrowserStack App Live.

The Appetize build path is unchanged. The BrowserStack path uses a separate `iphoneos` Release build and packages `Payload/Weektable.app` as an IPA. It does not put BrowserStack, OpenAI, database, or grocery-provider credentials in the app.

## GitHub secrets

Add these repository secrets under **Settings → Secrets and variables → Actions**:

- `BROWSERSTACK_USERNAME`
- `BROWSERSTACK_ACCESS_KEY`

The workflow never prints either value. When both are present, every successful BrowserStack device build is uploaded to the App Live endpoint with the stable custom ID `cove-ios`. When either is absent, CI still validates and retains the IPA, and the upload step is skipped with a clear notice.

The application URLs are public configuration, not secrets. Push builds currently embed:

- `COVE_RUNTIME_MODE=PRODUCTION_LIVE`
- `COVE_API_BASE_URL=https://cove-planner-delta.vercel.app`
- matching privacy, terms, and support URLs

Manual workflow runs can override those values.

## Signing model

The BrowserStack artifact is a physical-device IPA built without an Apple signing identity. Push builds use the Release configuration. A manually requested `STAGING_LIVE` build uses Debug so the existing Release safety gate remains intact. Fixture-only workflow runs continue to build Appetize and intentionally skip the real-device job. BrowserStack App Live's upload service re-signs uploaded iOS apps with its provisioning profile for installation on BrowserStack devices. This is separate from TestFlight and does not create an App Store build.

Apple Developer Program membership and Apple distribution credentials are still required for TestFlight or App Store distribution. When that is needed, add an Apple Distribution certificate, its private key, an App Store provisioning profile for `com.weektable.ios`, an App Store Connect API key, and an export step. Do not reuse the BrowserStack credentials for Apple signing.

## Manual upload endpoint

CI sends the IPA only to BrowserStack App Live:

```text
POST https://api-cloud.browserstack.com/app-live/upload
```

It does not use the BrowserStack Live website product or the App Automate upload endpoint.
