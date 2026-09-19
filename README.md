# MeloBridge

A cross-platform music client that uses Spotify metadata and resolves playback
through configurable audio providers.

## About this fork

MeloBridge is an independent fork of [Spotui](https://github.com/H4zh4n/Spotui).
It brings iOS support, prepares desktop support, and is not an official release
from either Spotify or the upstream Spotui maintainers.

The first milestone adds shared Kotlin models and Compose UI foundations, an iOS
app with local audio import and playback, and Android/iOS build workflows. Import, local playback,
background audio, and system controls have been tested on an iPhone 6s running
iOS 15 inside LiveContainer. Spotify sign-in and track search have also been
tested on the device. Playlist browsing and loading more than 50 tracks have
also been tested. The iOS playback path now tries Qobuz and then SoundCloud
using Spotify metadata; it awaits a remote build and device validation. The
remaining audio providers and full library browsing are not ported yet.
Desktop support is planned but not implemented.

The root navigation and design colors now come from Compose Multiplatform code
used by Android and iOS. The next priorities are to migrate the mini player and
feature screens into the same shared UI, move provider selection and resolution
into shared Kotlin code, port the remaining providers, and validate the Android APK.
See the [iOS build and SideStore/LiveContainer guide](docs/ios.md) for the unsigned IPA workflow
and the current limitations.

The project retains its [GNU GPL v3 license](LICENSE) and documents its origin
in [NOTICE.md](NOTICE.md).

## CI builds

The **Android APK** workflow runs when an `android-v*` tag is pushed, while the
**iOS unsigned IPA** workflow runs when an `ios-v*` tag is pushed. Neither runs
on ordinary branch pushes or pull requests. Both can also be started manually
from the Actions tab once the workflows are present on the default branch.

To build only one platform from a particular commit, tag that commit and push
the tag (use a new tag name for each build):

```sh
git tag android-v0.1.0-test1
git push origin android-v0.1.0-test1
# Or, for iOS:
git tag ios-v0.1.0-test1
git push origin ios-v0.1.0-test1
```

The Android workflow runs unit tests and builds the release APK. Artifact and
file names include the platform tag and short commit, for example
**MeloBridge-android-v0.1.0-test1-a1b2c3d** and
**MeloBridge-android-v0.1.0-test1-a1b2c3d.apk**. The version shown by the installed
app comes from the tag; its monotonically increasing version code is derived
from the GitHub Actions run. The APK uses the
existing shared debug signing key configured in the project; no signing secrets
are required. Extract the downloaded artifact ZIP to install the APK.

The workflows run independently; push both kinds of tag at the same commit to
build both platforms. The first remote Android build still needs to be validated.
The cross-platform migration plan is documented in
[docs/architecture.md](docs/architecture.md).

## 💖 Support the upstream project

The original project's sponsorship link is preserved below to support its author.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/hazhan)

_____________

## Android features

It connects to your real Spotify account and mirrors the Spotify experience.

- 🎵 **Playlists** — browse, play, add/remove tracks, create new playlists, all synced with your Spotify account
- 📝 **Lyrics** — Spotify's own synced lyrics, with a live preview on the player and a full-screen view
- 📻 **Spotify recommendations** — the queue continues with Spotify's real track radio (autoplay), so "up next" matches what open.spotify.com would play
- ❤️ Liked songs, followed artists, listening history and downloads (including lossless FLAC)

## Screenshot

<p align="center">
  <img src="https://github.com/user-attachments/assets/dfd41cd7-92a8-46d5-800d-a4ecfddfeef8" width="32%" alt="Screenshot_2026-07-13-21-03-36-065_com music spotui" />
  <img src="https://github.com/user-attachments/assets/64e1a3d7-fef0-422e-aa80-276e5b66d874" width="32%" alt="Screenshot_2026-07-13-21-01-15-466_com music spotui" />
  <img src="https://github.com/user-attachments/assets/a64f54b3-f69c-4073-970d-d189d5ed5da5" width="32%" alt="Screenshot_2026-07-13-20-43-45-056_com music spotui" />
</p>

## Credits

MeloBridge builds on the work of several open-source projects:

- [Meld](https://github.com/) — Spotify metadata + YouTube streaming layer
- [Neptune](https://github.com/navneet851/spotify-clone-jetpack-compose) — the original Jetpack Compose Spotify clone this app started from
- [SpotiFLAC](https://github.com/spotbye/SpotiFLAC) — lossless (FLAC) track resolving
- [SimpMusic](https://github.com/maxrave-dev/SimpMusic) — crossfade / DJ-style audio filter processing

## Disclaimer

This project is for educational purposes only. Spotify is a trademark of Spotify AB.


### 🌟 Inherited Android improvements
The Android codebase includes an overhauled lossless audio engine, offline caching, and various UI improvements documented before this fork's iOS work.
➡️ **[Click here to read the full list of features and differences](CHANGELOG.md)**
