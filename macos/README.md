# YouTube Music for macOS

A compact native menu-bar player adapted from the Omarchy plugin. The menu bar
shows one custom wave icon. Click it to open the 340 × 460 player; hover for track details.

## Run

Open `YouTube Music.app`. It stays in the menu bar and keeps playing when the
popup closes. Right-click its icon for the player menu and Quit.

Click the search icon at the top right or press Command-K to expand the search
capsule leftward within the header. The magnifier stays at its right edge. Search
runs after a short pause while typing. Results fill the player, as in the
Omarchy plugin. Click a result once or select it and press Return to play.
Choosing a result collapses search and returns to centered artwork, transport
controls, and Up next. Clearing the query returns to the current queue.
Choosing a search result starts its mix. The queue advances at
the end of each track and requests more recommendations near the end. YouTube
can return a finite mix or repeated recommendations, so a station can end.

- Play/pause, previous, next, seek, and per-track mixes. Volume is in the menu-bar icon's right-click menu.
- Command-K toggles the header search field. Down moves from search into the result list.
- Arrow keys select a row. Return plays it. Space toggles playback outside text fields.
- Command-Left and Command-Right change tracks. Escape closes the popup.
- macOS Now Playing and media-command integration.
- The queue and volume survive restarts. Relaunching restores the queue paused.

This uses public YouTube search, without Google sign-in. Search is general
YouTube search; adding `music` or `soundtrack` can narrow broad queries.
Unavailable, restricted, or unsupported tracks may fail. The player tries the
next queued track and stops after three consecutive failures.

## Build

Requires macOS 13 or newer, Apple Command Line Tools, and Python 3. Full Xcode,
Homebrew, mpv, jq, and socat are not required for the Mac app.

```sh
./macos/build.sh
open "macos/dist/YouTube Music.app"
```

The build downloads pinned official yt-dlp and Deno releases, verifies their
published SHA-256 digests, and bundles them. The first build needs internet
access. Later builds use the verified cached files. The build targets the
current Mac's architecture. The initial packaged app is for Apple silicon.

The app uses AppKit and AVPlayer. Search, mix, and stream requests have separate
cancellation tokens, so late results cannot replace a newer selection. There is
only one AVPlayer instance. macOS audio playback does not use the Linux shell
backend or its runtime files.

The build is locally ad-hoc signed. It is not Developer ID signed or notarized
for public distribution. Vendor binaries retain their original signatures.
Signing happens in a temporary folder to avoid iCloud Finder metadata being
attached during the signing step.

## Checks

```sh
./macos/check.sh
```

Checks cover parsing, video ID validation, deduplication, queue boundaries,
saved-state validation, stale search/mix/stream responses, repeated failures,
search toggling, typing debounce, full-height results, one-action selection, and
clearing search back to the queue.
GitHub Actions also compiles the app on macOS.

Verified on an Apple silicon Mac running macOS 15.7.9:

- Official bundled tools searched YouTube and resolved an AAC audio stream.
- A muted AVPlayer check decoded the stream and advanced over two seconds.
- The actual app loaded a 40-track Zelda mix and played a track with an advancing progress slider.
- Restarting the compact build restored that queue paused.
- The native 340 × 460 view was rendered for layout inspection.
- Local app bundle signature verification passed before copying it to Documents.

The Linux GUI cannot be exercised on this Mac. Its backend regression tests run
on Ubuntu in GitHub Actions.

## Source layout

- `Sources/Models.swift`: tracks, parsing, queue rules, persistence shape.
- `Sources/YouTubeClient.swift`: bundled extractor, cancellation, request timeout.
- `Sources/PlayerStore.swift`: playback, mixes, queue state, media commands.
- `Sources/PlayerViewController.swift`: compact AppKit player and result list.
- `Sources/main.swift`: menu-bar icon, popup lifecycle, menus, single-instance check.
- `Tools/fetch-dependencies.py`: pinned download URLs and checksums.

Update the release URLs and digests in `fetch-dependencies.py` when a YouTube
change requires a newer extractor, then rebuild. No files are downloaded or
executed from a user-supplied search string, and external tools receive arguments
directly rather than through a shell.

The Mac app stores its queue and volume in the standard UserDefaults domain
`io.github.itsdotdev.youtube-music.macos`. It stores no Google credentials or
stream URLs. Third-party notices are included in the app's Resources folder.

The custom app and menu-bar artwork and its generation prompts are saved in
`Resources/`. The player has no three-dot menu; use the menu-bar icon's right-click menu.
