# PunchCard Mobile — Design Brief

Share this (plus screenshots) with a design-focused Claude chat to refine the look.

---

I'm refining the look of a React Native app. Constraints before you suggest anything:

## Stack

- Expo SDK 54, TypeScript, expo-router (file-based routes)
- UI: react-native-paper v5 (Material 3), react-native-paper-dates
- No other UI lib. Paper components + react-native-svg already installed. If you propose something outside Paper, tell me what it costs.
- Must render correctly in both light and dark mode (`userInterfaceStyle: automatic`)
- `newArchEnabled: true` — avoid libs that don't support the New Architecture

## Theme

- Default Paper `MD3LightTheme` / `MD3DarkTheme`
- Splash and Android adaptive-icon background color: `#F1EFE6` (cream)
- App icon is a retro green mechanical punch clock on cream, with orange / yellow-green geometric rectangles behind it. Palette cues I'd take from the icon:
  - deep teal-green `#2F504B`
  - cream `#F1EFE6`
  - rust-orange `#C05A35`
  - olive-green `#7A8A43`
  - mustard-yellow `#D9A43A`

## What the app is

Companion to a Swift CLI that logs work sessions and syncs to a Google Sheet via a webhook. Phone app's job: start/stop sessions, log notes, enter past sessions, manage projects, share config via QR.

Single-user, personal-scale. No login, no multi-tenant anything.

## Screens (see attached screenshots)

1. **Home / Status** — active session card or idle "Punch In" CTA
2. **Punch In** — segmented Now/Past; Now has start-time chips, Past has start+end date-time pickers + summary
3. **Punch Out** — summary field, computes hours
4. **Log Note** — one-line note append to active session
5. **Settings** — webhook URL, secret (hidden), enable toggle, Test button
6. **Settings → Projects** — add/remove projects
7. **Settings → Share QR** — renders QR of current config
8. **Settings → Scan QR** — camera scanner modal

## What I want

<!-- Fill this in before sharing. Examples:
  - "Punch-in should feel more delightful"
  - "Dark mode looks flat"
  - "Settings is a wall of cards, tighten it"
  - "Add a subtle brand mark to Home"
  - "The Home idle state is boring"
  - "Lean harder into the retro icon palette"
-->

## What not to touch

- Navigation structure (expo-router modals for punch-in/out/log)
- Data flow / state management (Zustand + Room/SQLite + sync dispatcher)
- QR code rendering (functional — just don't regress)
- Sync-queue badge behavior on Home

## Delivery format

Per-screen specific changes (component names, prop deltas, theme overrides) I can apply in code. Prefer Paper theme customization via `PaperProvider` over per-component style hacks. Keep the diff small; don't re-architect.
