# iOS port — first milestone

## Current status

This first milestone lays the groundwork for the port. It does not yet provide
feature parity with Android: Spotify sign-in, search, and library browsing are
not available on iOS.

Implemented:

- A `shared` Kotlin Multiplatform module targeting JVM, ARM64 iPhone/iPad devices,
  and the Apple Silicon simulator. Existing Spotify models have been moved here
  without changing their packages or serialized fields. The `spotify` module
  re-exports them to Android through an `api` dependency.
- An app requiring iOS/iPadOS 15 or later: import from Files, persistent copies
  in the app's private storage, deletion, native AVPlayer playback, pause,
  seeking, and previous/next controls.
- Background audio configuration, lock-screen controls, audio interruption
  handling, and pausing when headphones disconnect. These require device testing.
- A macOS workflow that tests shared code and builds an unsigned ARM64 IPA.
  Producing this artifact requires no Apple account or credentials.

The SwiftUI interface is an initial shell for validating native playback. Android
screens have not yet been migrated to Compose Multiplatform. This shell allows
installation and audio testing independently of that migration. The shared module
can also be used by the future desktop application.

Validation completed so far: 3 shared-module tests and 19 existing Spotify
module tests pass. YAML, plist, and shell script syntax have been checked.
The full Android build has not yet been validated; it requires a configured
Android SDK. The iOS build has not yet been run; no IPA has been produced yet.

## Producing the IPA with GitHub Actions

These steps work from any desktop OS with a web browser, including Windows,
macOS, and Linux. GitHub runs the build on a hosted macOS runner, so you do not
need Xcode or a local Mac to use this workflow.

1. Push these changes to your GitHub repository with Actions enabled.
2. Open **Actions → iOS unsigned IPA**. A push affecting the relevant files
   triggers a build. **Run workflow** also allows manual runs once the workflow
   is present on the default branch.
3. Wait for both jobs to succeed. Download the **Spotui-iOS-unsigned** artifact.
4. Extract the downloaded ZIP to obtain **Spotui-unsigned.ipa**.
5. Save the IPA in Files on your test iPhone or iPad, then follow the
   LiveContainer instructions below.

The remote build must succeed before an IPA is available. A successful build
does not replace runtime testing on an iPhone or iPad.

## Sideloading with SideStore and LiveContainer

The intended test setup uses SideStore and LiveContainer, already installed and
configured on the device. For host installation and setup, follow the
[official LiveContainer guide](https://livecontainer.github.io/docs/installation)
and [SideStore documentation](https://docs.sidestore.io/docs/installation/install).

1. Open LiveContainer and use its IPA import action to select
   **Spotui-unsigned.ipa** from Files.
2. Wait for the import to finish, then launch Spotui from LiveContainer.
3. Run the device checks below. Record the iOS and LiveContainer versions when
   reporting problems.

Spotui has not yet been tested inside LiveContainer. In particular, file imports,
background playback, and lock-screen controls need device validation. Targeting
iOS 15 does not by itself guarantee compatibility with the installed host.

If import, launch, or audio behavior fails in LiveContainer, try installing the
same IPA directly with SideStore's IPA installation action. This signs and
installs Spotui as a standalone app and provides a comparison outside the host.
Keep SideStore's required pairing and VPN setup available as described in its
documentation.

With a free Apple account, refresh the apps signed through SideStore before their
seven-day expiry. For the LiveContainer setup, keep the signed host and SideStore
refreshed; if Spotui is installed directly, refresh it as well. An IPA imported
inside LiveContainer is not a separate standalone SideStore installation.

## Testing on an iPhone or iPad

The baseline test device is an iPhone 6s running iOS 15. The app targets iOS 15.0
and uses `NavigationView` with stack styling instead of the iOS 16-only
`NavigationStack`. Kotlin 2.4.0 also defaults to a minimum iOS version of 15.0.
The CI simulator uses a newer iOS runtime, so a successful CI build does not
replace testing on this physical device.

1. Import two MP3/M4A files from Files, including one from iCloud if available.
2. Check play/pause, seeking, previous/next, and automatic advancement to the
   next track. An unsupported format should display an error.
3. Lock the screen and check that audio continues and system controls work.
4. Disconnect headphones: playback should pause. Also test an audio interruption
   and recovery afterward.
5. Close and reopen the app: imported files should still be present.
6. Delete a track: it should disappear, and playback should stop if that track
   was playing.

## Development

Run the shared and Spotify JVM tests from the repository root with JDK 17
installed and `JAVA_HOME` configured. These tests do not require an Android SDK.

On macOS or Linux:

```sh
bash gradlew -PsharedOnly=true :shared:jvmTest :spotify:test
```

On Windows (PowerShell or Command Prompt):

```powershell
.\gradlew.bat -PsharedOnly=true :shared:jvmTest :spotify:test
```

Local iOS compilation requires macOS, JDK 17, Xcode, and XcodeGen. From the
repository root, run:

```sh
bash scripts/build-ios.sh
```

On Windows, Linux, or any machine without Xcode, use the GitHub Actions workflow
above to compile iOS. Editing the source and running the JVM tests does not
require a local iOS toolchain.

`iosApp/project.yml` is the source for the generated Xcode project, which is not
committed. The static Kotlin framework is built by the Xcode
`embedAndSignAppleFrameworkForXcode` phase. The unsigned build produces a
`Payload/Spotui.app` package rather than an App Store/TestFlight export.

The existing Android toolchain uses Kotlin 2.4.0 and Gradle 9.6.1. This Gradle
version exceeds Kotlin 2.4.0's officially supported range (up to 9.5). It is
retained here to avoid changing the Android toolchain at the same time. JVM tests
provide regression coverage; the remote native build still needs validation.
The workflow selects Xcode 26.4.

## Next steps

1. Port the Spotify client and authentication: multiplatform Ktor networking,
   Keychain storage for secrets, and iOS sign-in. The current implementation
   depends on Java, WebView cookies, and Spotify internals; WebKit compatibility
   must be tested and is not guaranteed.
2. Share repositories and screen state, then migrate library browsing and
   search to Compose Multiplatform.
3. Port stream resolution and connect remote tracks to the iOS player.
   The YouTube/NewPipe engine, decryption, and lossless providers each require
   adaptation; none is active in this initial version.
4. Add downloads, lyrics, and feature parity, then desktop support.

## References

- [Kotlin/Xcode integration](https://kotlinlang.org/docs/multiplatform-direct-integration.html)
- [Kotlin Multiplatform tool compatibility](https://kotlinlang.org/docs/multiplatform/multiplatform-compatibility-guide.html)
- [Kotlin 2.4.0 Apple deployment targets](https://kotlinlang.org/docs/whatsnew24.html#changes-to-apple-target-support)
- [XcodeGen configuration](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md)
- [Apple accounts and Personal Team limitations](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [LiveContainer installation](https://livecontainer.github.io/docs/installation)
- [SideStore installation and setup](https://docs.sidestore.io/docs/installation/install)
