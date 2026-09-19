# Cross-platform architecture

MeloBridge currently has a mature Android application and a smaller iOS client.
Adding each feature twice would preserve the existing behavior gaps, so product
behavior and UI are being moved into Kotlin and Compose Multiplatform. Native code
remains responsible for playback and operating-system integrations.

## Target boundaries

`shared` owns Spotify metadata, provider selection and matching, pagination,
session-independent use cases, presentation state, design tokens, and shared
composables. Android and iOS provide adapters for secure storage, web
authentication, media sessions, audio engines, and file pickers.

Both clients render shared Compose components. The first migrated component is
the Home, Search, and Library navigation bar. Screens and the mini player remain
platform implementations until their state and actions are moved behind common
interfaces. Shared colors include background `#0B0B0F`, surface `#2A2A2A`, brand
accent `#618DFF`, and Spotify green `#1ED760`.

## Supported platforms

The application baseline is Android 8.0 (API 26) and iOS/iPadOS 15.0. The Android
app and the Android target of `shared` both declare API 26. The Xcode project
declares iOS 15.0. APIs introduced after those versions must use runtime version
checks or platform adapters so they do not raise the installation minimum.

iOS 15 is validated on an iPhone 6s. Android API 26 is the configured support
target but still needs runtime validation on an API 26 device or emulator. CI
compiles Android against API 37 and tests the iOS shared code on the simulator;
those checks do not replace minimum-version device testing.

## Migration order

1. Stabilize builds and diagnostics. Every artifact carries its platform, tag or
   manual run, commit, semantic version, and build number.
2. Move provider matching and fallback decisions into `shared`, with fixture-based
   tests. Keep HTTP and playback adapters platform-specific at first.
3. Define shared screen state and actions for Search, Library, playlists, and the
   queue. Replace direct networking from SwiftUI and Android view models.
4. Move the navigation shell, mini player, typography, colors, artwork, loading,
   empty, and error states into shared Compose. The root navigation and colors
   are the first completed part of this step.
5. Migrate remaining Android-only features one vertical slice at a time. A slice
   is complete only when its shared tests and both platform clients work.
6. Add the desktop client after shared state and provider resolution no longer
   depend on Android classes.

Large Android classes are split while their behavior is covered by tests. Each
screen switches to the common implementation only after both platform adapters
provide the actions it needs, which keeps playback and authentication usable
during the migration.
