# Build Weektable for Appetize from Windows

Appetize accepts a ZIP containing an iOS Simulator `.app` bundle. It does not
accept Swift source code, an Xcode project, or an App Store/device `.ipa`.
Because the `.app` must be linked against Apple's iOS Simulator SDK, the final
ZIP has to be compiled on macOS. No Apple Developer membership, certificate,
provisioning profile, or OpenAI API key is needed for this demo build.

The project includes two reproducible cloud-build options. Both create a file
named `Weektable-Appetize.zip`. Use either option, not both.

## Option A: Codemagic

1. Extract `Weektable-Cloud-Build-Source.zip` on Windows.
2. Create a new empty GitHub repository. Private is fine.
3. Upload the extracted contents so `codemagic.yaml`, `ios`, `shared`, and
   `.github` are at the repository root.
4. Sign in at <https://codemagic.io> and choose **Add application**.
5. Connect the repository and select **Codemagic YAML** as the project type.
6. Start the workflow named **Weektable - Appetize Simulator Build**.
7. When the build succeeds, download `Weektable-Appetize.zip` from **Artifacts**.

## Option B: GitHub Actions

1. Extract `Weektable-Cloud-Build-Source.zip` on Windows.
2. Create a new GitHub repository and upload the extracted contents at its root.
3. Open the repository's **Actions** tab.
4. Select **Build Weektable for Appetize**.
5. Choose **Run workflow**, then wait for the green checkmark.
6. Open the completed run. Under **Artifacts**, download
   `Weektable-Appetize`.
7. GitHub downloads an outer artifact ZIP. Extract it once. The inner file named
   `Weektable-Appetize.zip` is the file for Appetize.

## Upload to Appetize

1. Sign in at <https://appetize.io>.
2. Create a new app or open the upload page.
3. Select **iOS** and upload `Weektable-Appetize.zip` without extracting it.
4. Launch an iPhone running iOS 17 or newer.
5. The app starts at the Weektable welcome screen. Tap **Plan my week** to test
   onboarding, planner steps, generation, week view, recipe details, groceries,
   and meal swapping.

## What is inside the build

- Native SwiftUI app; there is no WebView.
- ARM iOS Simulator executable for Appetize.
- Offline demo repository with deterministic meals and grocery pricing.
- No embedded secret or OpenAI API key.
- iOS 17 minimum deployment target.

## If the cloud build fails

Download the `Weektable-Xcode-Log` artifact (GitHub) or `xcodebuild.log`
(Codemagic). The final lines identify the failing Swift file and line. Do not
upload the log to Appetize.

