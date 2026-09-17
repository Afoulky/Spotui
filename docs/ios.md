# iOS port — first milestone

## Current status

This first milestone lays the groundwork for the port. It does not yet provide
feature parity with Android: Spotify track playback and full library browsing
are not available on iOS. Sign-in and track search work on the test device;
playlist browsing has been implemented but awaits device validation.

Implemented:

- A `shared` Kotlin Multiplatform module targeting JVM, ARM64 iPhone/iPad devices,
  and the Apple Silicon simulator. Existing Spotify models have been moved here
  without changing their packages or serialized fields. The `spotify` module
  re-exports them to Android through an `api` dependency.
- An app requiring iOS/iPadOS 15 or later: import from Files, persistent copies
  in the app's private storage, deletion, native AVPlayer playback, pause,
  seeking, and previous/next controls.
- An initial Spotify sign-in and track search screen. It uses the same web-player
  token and persisted-query protocol as Android, stores the session cookie in
  iOS Keychain, and keeps access tokens in memory. Sign-in and track search
  have been tested on the iPhone 6s; Spotify's internal endpoints may change.
- A playlist browser with pagination and a view of the first 50 tracks in each
  playlist. It uses Android's `libraryV3` and `fetchPlaylist` queries and still
  needs a remote build and device test. Spotify tracks cannot be played yet.
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
The iOS workflow has produced an IPA that launches on the iPhone 6s test device.
Audio file selection, import, local playback while locked, and system media
controls work inside LiveContainer after enabling its **Fix File Picker** setting
for Spotui. Headphone disconnection, interruption recovery, and file persistence
still need device validation. The Android workflow has not yet produced a
validated APK.
Spotify sign-in, track search, session restoration after relaunch, and signing
out have been tested on the iPhone. The isolated temporary web login has also
been confirmed to require a new login after signing out.

## Producing the IPA with GitHub Actions

These steps work from any desktop OS with a web browser, including Windows,
macOS, and Linux. GitHub runs the build on a hosted macOS runner, so you do not
need Xcode or a local Mac to use this workflow.

1. Push these changes to your GitHub repository with Actions enabled.
2. Create a unique iOS tag on the commit you want to build, then push the tag:

   ```sh
   git tag ios-v0.1.0-test1
   git push origin ios-v0.1.0-test1
   ```

   Only tags matching `ios-v*` start this workflow; ordinary branch pushes and
   pull requests do not. **Run workflow** in **Actions → iOS unsigned IPA** also
   allows manual runs once the workflow is present on the default branch.
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

If the Files picker opens but **Open** does nothing after choosing an audio file,
return to LiveContainer, press and hold the Spotui app card, tap **Settings**,
enable **Fix File Picker** under **Fixes**, and launch Spotui again. LiveContainer
documents this setting for guest apps whose system file picker cannot select
files. On older LiveContainer versions, the equivalent
setting may be named **Fix File Picker & Local Notification**. If selection still
fails, try its **Fix File Picker (legacy)** option or install the same IPA
directly with SideStore to compare behavior. The legacy option copies selected
files into the guest app's Inbox, so check available storage before large imports.

Another route to test is **Files → select an audio file → Share → LiveContainer →
Spotui**. LiveContainer documents this as **Open In App** support. Spotui accepts
audio files sent through an open-document URL and copies them into its library.
This route has not yet been verified on the test iPhone; it may vary by
LiveContainer version and audio file type.

Spotui has been tested inside LiveContainer on an iPhone 6s running iOS 15.
File import, playback while locked, and system media controls work with
**Fix File Picker** enabled. Headphone disconnection, interruption recovery,
and file persistence still need device validation.

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
   Both passed on the iPhone 6s running Spotui inside LiveContainer.
4. Disconnect headphones: playback should pause. Also test an audio interruption
   and recovery afterward.
5. Close and reopen the app: imported files should still be present.
6. Delete a track: it should disappear, and playback should stop if that track
   was playing.
7. On the Spotify tab, test web sign-in and search. If the web login cannot
   complete, the manual `sp_dc` field is a fallback. Verify that signing out
   removes the session and that a relaunch restores a saved session. Search
   results display metadata only; selecting a Spotify track cannot play it yet.
8. Open **Playlists** on the Spotify tab, load additional pages, then open a
   playlist to check its first 50 tracks. Spotify track playback is not yet
   available.

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

1. Validate playlist browsing on device, then harden iOS Spotify sign-in and
   track search. The initial native implementation duplicates Android's
   token and search protocol; move that protocol into shared code. Spotify's
   internal endpoints and WebKit login behavior may change.
2. Share repositories and screen state, then migrate the remaining library browsing and
   search presentation to Compose Multiplatform.
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
- [LiveContainer app settings and file picker fixes](https://livecontainer.github.io/docs/guides/app-settings)
- [SideStore installation and setup](https://docs.sidestore.io/docs/installation/install)
