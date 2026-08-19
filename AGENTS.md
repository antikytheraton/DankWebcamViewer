# AGENTS.md

Guidance for AI agents and contributors working on this plugin.

## What this is

`dankWebcamViewer` is a [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) (DMS) plugin built on Quickshell. It adds a bar widget that launches RTSP/RTMP camera streams in an external player (`vlc`, `ffplay`, or `mpv`) and provides a popout with a grid of camera cards plus a settings page for managing the camera list.

Plugin id: `webcamViewer`. License: AGPL-3.0-or-later.

## File map

- `plugin.json` — DMS manifest. `id` must equal the `pluginId` used in both QML files. Declares widget type, `component`, `settings`, `permissions` (`settings_read`, `settings_write`, `process`), and `requires` (`vlc`, `mpv`, `ffmpeg`).
- `WebcamViewer.qml` — the widget component (`PluginComponent` with `pluginId: "webcamViewer"`). Contains the horizontal + vertical bar pills and the popout.
- `WebcamViewerSettings.qml` — the settings page (`PluginSettings`). Edits the stored camera list.
- `test.sh` — validation script (see Verification).
- `assets/` — README screenshots.

## How it works

### Plugin data
The camera list is read from `pluginData.cameras` (an array of `{ name, url, enabled }`) and passed through `enabledCameras = cameras.filter(c => c.enabled !== false)`. The player is selected via `pluginData.player` and defaults to `vlc`.

### Launching a stream (`WebcamViewer.qml`)
Per-player shell command builders are stored in the `players` object (`vlc` / `ffplay` / `mpv`). `launchCamera()` creates a `Process` object from `processComponent`, sets `proc.running = true`, and records it in `runningStreams[name]`. `stopCamera()` sets `proc.running = false`, deletes the entry, and shows a `ToastService` message. When a process exits (e.g. player window closed) its `onExited` handler cleans up its own `runningStreams` entry.

Base `Process` comes from `import Quickshell.Io`.

### Live-state bookkeeping
- `runningStreams` maps "camera name" → `Process`.
- `activeCount` is computed from `Object.keys(runningStreams).length` and drives the bar label (`2/3 live`), a pulsing green dot, icon/color emphasis, and per-card `live` state.
- Bar label logic: when active it shows `<active>/<enabled> live`, otherwise `<n> cam/cams`.

### Credentials & URLs
`strippedUrl()` replaces the `user:pass@` part of a URL with `//` and truncates to ~35 chars so credentials never render in the popout or settings.

### Settings (`WebcamViewerSettings.qml`)
The camera array is stored as a JSON array under the key `cameras` in `plugin_settings` (via `PluginSettings.saveValue`/`loadValue`). Persistent state flows through a `cameraList` working copy. Edits use `updateCamera` → **deep copy** (`JSON.parse(JSON.stringify(...))`) then reassign `cameraList` — never mutate the array in place. Settings also exposes a `player` selection via `SelectionSetting`.

There is no raw `TextInput` widget exposed in the settings context, so name/URL fields are a styled `Rectangle` + `TextInput` combo that persists on `editingFinished`.

## Conventions & gotchas

- Reassign a QML property to force binding refresh after mutation, e.g. `runningStreams = runningStreams;` — this pattern is used deliberately to re-evaluate `live`, `barLabel`, etc.
- Start with `Theme.*` tokens and the shared widgets (`StyledText`, `StyledRect`, `DankIcon`, `PopoutComponent`, `ToastService`) from `qs.Common` / `qs.Widgets` / `qs.Services` — do not introduce new styling primitives.
- `plugin.json` `id`, `component`, and `settings` paths must stay consistent with the QML `pluginId` (enforced by `test.sh`).
- Keep `version` in `plugin.json` in semver format.
- Don't add code comments unless asked; existing files use `// ── section ──` separators — match that style if adding comments.

## Verification

Run after any changes:

```
./test.sh
```

It validates that `plugin.json` is valid JSON with the correct `id`/`name`, contains all required fields, uses semver, the `component`/`settings` files exist, and `pluginId` in both QML files matches the JSON `id`. Exit code is non-zero on any failure.