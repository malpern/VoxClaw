# Changelog

All notable changes to VoxClaw are documented here. Earlier releases are on the
[GitHub releases page](https://github.com/malpern/VoxClaw/releases).

## Unreleased

### Added
- **Cross-device iCloud relay** — your Mac can speak agent output on your
  iPhone/iPad even when it's locked, backgrounded, or off your LAN. The Mac
  writes the request to your **private** CloudKit database
  (`iCloud.com.malpern.voxclaw`), which silent-pushes and wakes the device to
  read it aloud. Opt-in on both ends ("Relay to my devices over iCloud" on the
  Mac, "Remote Relay" on iOS); both must be on the same iCloud account.
- **iOS app additions** — a Control Center control and home-screen widget
  ("Read Clipboard"), a "Read Text Aloud" Siri/Spotlight/Shortcuts action, and
  a "Now reading" Live Activity (lock screen + Dynamic Island). The app ships to
  internal testers via TestFlight.

### Fixed
- **Relay voice fidelity** — relayed speech now reproduces the sender's engine,
  voice, **rate, and prosody** instead of falling back to the receiving device's
  defaults.
- **Relay dedup** — the receiver advances its watermark to the newest record it
  actually fetched (sender clock) rather than its own wall clock, so messages
  are no longer skipped or duplicated under clock skew.

## v1.4.1

### Added
- **Liquid Glass overlay background** — an optional teleprompter background that
  uses the system Liquid Glass material (tinted by your chosen color), so it
  inherits macOS 27's translucency and readability. Toggle it in overlay
  appearance settings; off by default.

## v1.4.0

In-app auto-update via Sparkle.

### Added
- **Automatic updates** — VoxClaw now updates itself with [Sparkle](https://sparkle-project.org).
  New versions are downloaded and installed in place; downloads are notarized and
  EdDSA-signed end to end.
- **"Check for Updates…"** menu item to check on demand.

Note: this is the first Sparkle-enabled build, so install it once manually
(download below). From here on, future updates arrive automatically.

## v1.3.0

The ElevenLabs release — tight word-highlight sync, per-agent voices, and
politer multi-agent behavior.

### Added
- **ElevenLabs voice engine** with the tightest word-highlight sync of any engine,
  driven by ElevenLabs' server-side character timestamps (no more estimated timing).
- **Per-request engine override** — `POST /read` accepts `"engine": "apple" | "openai" | "elevenlabs"`
  to choose the engine per call, independent of the global setting.
- **Distinct voice per agent** — pass `project_id` + `agent_id` and each concurrent
  agent is auto-assigned its own voice from the engine's pool.
- **Hook installer safety** — `setup-claude-code.sh` now runs `bash -n` on each hook
  and refuses to install one with a syntax error, so a broken hook can't overwrite a working one.

### Changed
- **Calmer ElevenLabs delivery by default** — style exaggeration off and balanced
  stability, so it reads naturally instead of like a sports announcer.
- **Current ElevenLabs model** — migrated to `eleven_flash_v2_5` (the previous
  `eleven_turbo_v2_5` is deprecated).
- **Click-anywhere speed slider** — click anywhere on the track to jump to that
  speed; previously only the thumb was draggable.
- **Agent-aware hooks** — the Claude Code and Codex hooks now send the agent session
  id so each agent is tracked independently.

### Fixed
- **ElevenLabs highlight sync** — the timestamp parser now reads the API's current
  `character_*_seconds` schema; it had been silently falling back to estimated timing.
- **Multi-agent interrupts** — prompting one agent no longer cuts off another agent
  that is still speaking. Acks are scoped to `(project, agent)`, so concurrent agents
  queue politely instead of stopping each other.
