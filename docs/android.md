# Android development and testing

## Supported versions

MeloBridge supports Android 6.0 (API 23) and later. The application, Innertube,
and the Android target of the shared module all declare `minSdk = 23`. This is
the lowest version supported by the pinned Compose and AndroidX dependency set.

The project compiles and targets the stable Android 16 SDK (API 36). Compose
Multiplatform is pinned to 1.11 and Jetpack Compose to the `2026.06.00` BOM;
newer releases that require a preview SDK must not be adopted until that SDK is
stable. The compilation and target values do not change the installation
minimum.

Features introduced after API 23 use runtime checks or core library desugaring.
This includes `java.time`, Android 12
Bluetooth permissions and routing features, Android 12 dynamic colors, and
Android 13 notification permissions. Android API 23 is the configured baseline
but still needs runtime validation on an emulator or physical device before the
project can claim a fully tested Android 6 experience.

## Local requirements

- JDK 17
- Android Studio or the Android command-line tools
- Android SDK Platform 36
- Android SDK Platform Tools for `adb`

Set `ANDROID_HOME` or add the SDK path to an untracked `local.properties` file:

```properties
sdk.dir=/absolute/path/to/Android/Sdk
```

## Build and install

On Linux or macOS, run:

```sh
./gradlew :app:assembleDebug
```

On Windows, run:

```powershell
.\gradlew.bat :app:assembleDebug
```

The APK is written under `app/build/outputs/apk/debug/`. Install the generated
file from Android Studio or with `adb install -r <path-to-apk>`.

Run the JVM test suites with:

```sh
./gradlew :shared:jvmTest :spotify:test :app:testDebugUnitTest
```

## GitHub Actions

The unified **Build MeloBridge** workflow can build Android alone or together
with iOS. Push one new tag by itself:

```sh
# Android only
git tag android-v0.1.0-test1
git push origin android-v0.1.0-test1

# Android and iOS from the same commit
git tag all-v0.1.0-test1
git push origin all-v0.1.0-test1
```

The workflow can also be launched manually with the `android` or `all` target.
It installs Android SDK Platform 36, runs shared and Android unit tests, builds a
release APK, and uploads the APK and available test reports.

## Device checks

Test at least one API 23 device or emulator and one current Android version.
Check the following before declaring a release compatible:

1. Install, launch, Spotify sign-in, sign-out, and session restoration.
2. Home, Search, Library, playlists with more than 50 tracks, and navigation.
3. Playback through each enabled provider, seeking, queue changes, and errors.
4. Background playback, notification controls, lock-screen controls, and audio
   focus interruptions.
5. Wired and Bluetooth output changes. On Android 12 or later, also check the
   Bluetooth permission flow and output switcher.
6. Local-file import, downloads, persistence after relaunch, and deletion.
7. Spotify deep links. On Android 12 or later, check the default-link setup flow.

Record the Android version, device model, build tag, and provider when reporting
a failure. A successful API 36 CI build confirms compilation, not API 23 runtime
behavior.
