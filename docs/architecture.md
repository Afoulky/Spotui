# Cross-platform architecture

Spotui currently has a mature Android application and a small native iOS shell.
Adding each feature twice would preserve the existing behavior gaps, so new work
should move product behavior into Kotlin Multiplatform while keeping native UI and
platform playback integrations.

## Target boundaries

`shared` owns Spotify metadata, provider selection and matching, pagination,
session-independent use cases, queue rules, and presentation state that can be
tested without Android or iOS. Android and iOS own screens, navigation, secure
storage, web authentication, media sessions, audio engines, and file pickers.

The two clients use the same information architecture and design constants:
Home, Search, and Library root destinations; a persistent mini player; dark
background `#0B0B0F`; accent `#618DFF`; and equivalent loading, empty, and error
states. A platform may use native controls and spacing where that improves
accessibility.

## Migration order

1. Stabilize builds and diagnostics. Every artifact carries its platform, tag or
   manual run, commit, semantic version, and build number.
2. Move provider matching and fallback decisions into `shared`, with fixture-based
   tests. Keep HTTP and playback adapters platform-specific at first.
3. Define shared screen state and actions for Search, Library, playlists, and the
   queue. Replace direct networking from SwiftUI and Android view models.
4. Align the navigation shell, mini player, typography, colors, artwork, loading,
   empty, and error states on both clients.
5. Migrate remaining Android-only features one vertical slice at a time. A slice
   is complete only when its shared tests and both platform clients work.
6. Add the desktop client after shared state and provider resolution no longer
   depend on Android classes.

Large Android classes should be split while their behavior is covered by tests;
a full rewrite without those tests would make existing playback regressions hard
to distinguish from migration regressions.
