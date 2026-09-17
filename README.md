# Spotui [![Downloads](https://img.shields.io/github/downloads/H4zh4n/Spotui/total?style=for-the-badge&labelColor=0d1117)](https://github.com/H4zh4n/Spotui/releases)

A Spotify clone for Android, built with Jetpack Compose.

## About this fork

This is an independent fork of [Spotui](https://github.com/H4zh4n/Spotui),
bringing iOS support and preparing desktop support while retaining the Spotui name.
It is not an official release from the upstream maintainers.

The first milestone adds shared Kotlin models, an iOS app with local audio
import and playback, and Android/iOS build workflows. Import, local playback,
background audio, and system controls have been tested on an iPhone 6s running
iOS 15 inside LiveContainer. A new iOS Spotify sign-in and track search flow is
implemented but still needs a remote build and device validation. Spotify track
streaming and library browsing are not ported yet. Desktop support is planned
but not implemented.

The next priorities are to validate the new Spotify sign-in and search flow on
device, port library browsing and remote playback, and validate the Android APK.
See the [iOS build and SideStore/LiveContainer guide](docs/ios.md) for the unsigned IPA workflow
and the current limitations.

The project retains its [GNU GPL v3 license](LICENSE) and upstream credits.
The download badge above links to upstream releases, not builds of this fork.

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

The Android workflow runs unit tests and builds the release APK,
available in the **Spotui-Android-APK** artifact for 14 days. The APK uses the
existing shared debug signing key configured in the project; no signing secrets
are required. Extract the downloaded artifact ZIP to install the APK.

The workflows run independently; push both kinds of tag at the same commit to
build both platforms. The first remote Android build still needs to be validated.

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

spotui builds on the work of several open-source projects:

- [Meld](https://github.com/) — Spotify metadata + YouTube streaming layer
- [Neptune](https://github.com/navneet851/spotify-clone-jetpack-compose) — the original Jetpack Compose Spotify clone this app started from
- [SpotiFLAC](https://github.com/spotbye/SpotiFLAC) — lossless (FLAC) track resolving
- [SimpMusic](https://github.com/maxrave-dev/SimpMusic) — crossfade / DJ-style audio filter processing

## Disclaimer

This project is for educational purposes only. Spotify is a trademark of Spotify AB.


### 🌟 Inherited Android improvements
The Android codebase includes an overhauled lossless audio engine, offline caching, and various UI improvements documented before this fork's iOS work.
➡️ **[Click here to read the full list of features and differences](CHANGELOG.md)**
