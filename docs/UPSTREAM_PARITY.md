# Upstream parity audit

Reference: darrenprx/lolPing commit `f24a51e5a11c2b31dab72d89a571cc4025ad3c98`.
Scope: all local macOS features. Room creation/joining, LAN/relay transport, room identities and remote ping/emote delivery are intentionally excluded. The upstream fullscreen-game probe is Windows-only and has no macOS implementation.

Implementation checklist (validation evidence and limits are recorded separately below):

- [x] Eleven ping definitions, correct wheel and placed artwork, All In clash animation
- [x] Eight unique configurable wheel slots and configurable click center; click-select/place, native drag/drop, click preview, reset
- [x] Trigger selection (modifiers, Mouse 4/5, custom key), suppression and conflict validation
- [x] Adjustable drag threshold, optional trigger-click, configurable pause hotkey, enabled on launch
- [x] Ping size/duration, master volume/mute, independent hover tick
- [x] Multiple simultaneous pings (up to 60), full-screen/Spaces/multi-display overlay
- [x] Independent emote trigger/off, click emote, 8-slot editor, center and reset
- [x] All 44 bundled animated emotes with original sound, 3-second lifetime
- [x] Import/drop PNG/JPEG/GIF/WebP, at most 24 custom emotes; rename/remove; animation support
- [x] Emote size and sound controls
- [x] System/English/Chinese language selection and system light/dark appearance
- [x] Login startup, starts hidden on login
- [x] Status/permissions/reconnect, data folder, asset integrity, upstream/license links
- [x] Check updates after 10s/every 6h, manual check, notification, verified user-initiated DMG download
- [x] Existing Super Ping actions/Codex/context/capture timing and old settings remain compatible

## Validation — 2026-10-13

- `swift test`: 37 regression tests covering old settings/actions, capture ordering, URL/context escaping, gesture cancellation, configurable wheel/click dispatch, partial settings migration, emote deletion repair, conflicts, animation curves and update version/digest validation.
- `bash scripts/verify-parity.sh`: production rendering of all 11 Pings; all artwork and sound paths checked; all 44 animated WebP sources decoded with different frames at 0.1s and 0.8s; PNG thumbnails and native WAV audio variants found.
- The same integration harness imports an animated WebP into an isolated directory, decodes it, rejects duplicate and corrupt files, and removes it. It calls the production input handler with synthetic event objects and a recording-only injection callback: Mouse 4 drag/click replay, dual-trigger pass-through, Control emote routing, cancellation, foreign shortcut suppression and custom-key down/up pairing pass. It does not post test events to other applications.
- Inspected production renderer PNGs for the normal wheel, question mark and animated facepalm. Verified muted wheel textures through a real macOS graphics session; sandbox rendering can fall back to the unfiltered texture.
- Opened the signed universal 0.8.0 application. Accessibility reported connected. Inspected Controls, Ping wheel, Emotes and App views through native accessibility and screenshots.

## Explicit validation limits

A simulated input test is not a physical mouse test. The first SwiftUI-only editor failed real user acceptance. It was replaced with AppKit drag sources/drop targets and explicit click-select/place. Native UI automation then confirmed emote slot 1 changing from Unworthy (text) to Facepalm and Ping slots 1/2 swapping Danger and Push; both test changes were restored. The tool’s coordinate-only drag attempts did not confirm a drop, so physical drag/drop is not claimed as verified. Login startup is implemented through `SMAppService.mainApp` and the login Apple event; this session did not log out. Spaces/fullscreen and heterogeneous multiple-display configurations were not exercised. The update version/digest logic is tested; a future-version download/install was not run against the public release service. These limits are not marked as successful tests.

The settings use native SwiftUI/AppKit controls rather than recreating Electron's Fluent UI widgets. All room-specific controls and network transports are absent. macOS renders text, shadows and easing through AppKit, so this is functional parity with upstream parameters, not a claim of pixel-identical browser rasterization.

The original screenshot/Codex default is intentionally retained as the user's Super Ping extension. Unlike the upstream default-only visual Ping, a question mark can therefore launch its configured action.

