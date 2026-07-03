# Changelog

## v1.3 — 2026-07-03

### Fixed
- 🤖 **Claude sync no longer kills lid-closed sessions.** In "only when actually working" mode, iTerm2's *processing* flag flickers off during quiet stretches of a live turn (long tool calls, permission prompts, stream stalls). A single 4-second idle poll was enough to re-enable sleep — with the lid closed the Mac dozed off within seconds and Claude Code died with `socket disconnected`. Sleep is now re-enabled only after **60 seconds of continuous idle**; going active still disables sleep instantly.
- ✋ **Manual off now sticks.** Flipping the switch (or hitting the force-sleep hotkey) while Claude sync was holding sleep off used to get overridden on the next poll. Now a manual off suppresses sync until you manually turn stay-awake back on (or toggle the sync setting).

## v1.2 — 2026-07-03

### Added
- ⚙️ **Settings window** (gear button in the panel): everything below lives there.
- ⌨️ **Global hotkeys** — bind your own system-wide shortcuts for Toggle / force stay-awake / force normal sleep (Carbon `RegisterEventHotKey`, no Accessibility permission needed).
- 🤖 **Claude Code sync** — automatically disable sleep while a Claude Code instance is working and restore normal sleep when it stops. Two modes:
  - *Only when actually working* (iTerm2 only) — correlates iTerm2 "processing" sessions with ttys running `claude` via the iTerm2 scripting API (asks for Automation permission once);
  - *Whenever it's running* — any terminal, plain process check.
- 🎪 **Awake reminders** — a playful click-through overlay animation plays every N seconds while sleep is disabled, so you can't forget. 7 styles + Off, frequency 15 s – 5 min, Preview button. Styles: Dynamic Notch (Dynamic-Island-style expansion around the notch), Edge Glow, Lightning Comet, Corner Peeker (googly eyes included), News Ticker, DVD Bounce, Heartbeat.
- 🌡️ **Thermal warning** — when the system thermal state rises past normal (fair / serious / critical), a warning card slides out from under the menu bar; it also reminds you that a no-sleep Mac can't cool off by sleeping. Fires once per escalation.

### Changed
- Idle tray/panel/HUD icon is now a **gray bolt** (was a moon) — orange when sleep is disabled.
- Panel UI animates the toggle (spring), warning card removed, footer simplified to gear + Quit.
- Toggle HUD sits slightly lower under the menu bar.

### Removed
- CPU-based "working" heuristic for Claude sync (replaced by the iTerm2 API).

## v1.0 — 2026-07-01

Initial release: menu bar app that fully disables macOS sleep (`pmset -a disablesleep`) with one password prompt ever (surgical sudoers rule), pulsing orange tray bolt, SwiftUI panel + system-style HUD, crash-safe watchdog that always restores sleep, universal binary (arm64 + x86_64).
