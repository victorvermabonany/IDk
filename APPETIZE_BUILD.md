# Build Cove for Appetize from Windows

Appetize requires a ZIP containing an ARM iOS Simulator `.app`, so GitHub Actions or another macOS builder must compile it.

## GitHub Actions

1. Push the repository with `ios`, `shared`, `app`, and `.github` at the root.
2. Open **Actions** and choose **Build Cove for Appetize**.
3. Run the workflow and wait for all web checks and iOS tests to pass.
4. Download the outer `Cove-Appetize` artifact.
5. Extract it once. Upload the inner `Cove-Appetize.zip` to Appetize without extracting it again.

## Fixture versus live staging

The default Debug artifact uses `DEVELOPMENT_FIXTURE`, contains no secrets, and clearly labels fixture prices. A live staging artifact must be built with:

```text
COVE_RUNTIME_MODE=STAGING_LIVE
COVE_API_BASE_URL=https://...
COVE_PRIVACY_URL=https://.../privacy
COVE_TERMS_URL=https://.../terms
COVE_SUPPORT_URL=https://.../support
```

These are public client configuration values. OpenAI, PostgreSQL, and Kroger credentials stay on the backend. Do not describe a fixture Appetize build as live.

The Xcode target/scheme and generated `.app` bundle directory still use the compatibility name `Weektable`; the installed app display name is Cove.
