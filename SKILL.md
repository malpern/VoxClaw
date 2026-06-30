---
name: voxclaw
description: Give your agent a voice. Send text to a Mac running VoxClaw and hear it spoken aloud with OpenAI neural voices or Apple TTS.
homepage: https://github.com/malpern/VoxClaw
metadata: {"clawdbot":{"emoji":"🦀","requires":{"bins":["curl"]}}}
---

# VoxClaw — Voice Output for OpenClaw

VoxClaw is a macOS app that speaks text aloud. It runs on the user's Mac as a menu bar app and listens for text over HTTP. Send text from any machine on the LAN and VoxClaw reads it using OpenAI neural voices or Apple's built-in TTS.

This is useful when your agent runs on a remote server or headless machine and you want voice output on the user's local Mac.

By default, agents should speak a short final summary after non-trivial work completes. Live progress narration should remain opt-in.

## How It Works

VoxClaw runs an HTTP listener (default port 4140) on the user's Mac. To speak text, POST to the `/read` endpoint. The user hears the text immediately through their Mac speakers with a teleprompter overlay showing synchronized word highlighting.

## Fast Handoff (Human -> Agent)

If the human shares a `🦞 VoxClaw setup pointer`, use it directly. It includes:
- website pointer (`https://voxclaw.com/`)
- integration doc (`SKILL.md`)
- machine-specific `Speak URL` (`/read`)
- machine-specific `Health URL` (`/status`)
- machine-specific `Agent Notify URL` (`/agent-notify`)

Prefer those provided URLs over guessed hostnames when both are available.
Never auto-switch to `.local` hostnames. Use numeric LAN IP URLs unless a human explicitly provides a `.local` target.
If `health_url`, `speak_url`, or `agent_notify_url` are present in the pointer, do not ask for LAN IP or run discovery first; call `health_url` immediately, then use the provided URLs.

Reliable connect order:
1. Confirm on VoxClaw Mac: `curl -sS http://localhost:4140/status`
2. Confirm from agent host: `curl -sS http://<lan-ip>:4140/status`
3. Send direct speech to `<lan-ip>:4140/read`
4. Send final summaries, failures, and opt-in progress updates to `<lan-ip>:4140/agent-notify`
5. If step 1 passes but step 2 fails, treat as network/firewall issue (not app API issue).

## API

### Speak Text

```bash
curl -X POST http://<mac-ip>:4140/read \
  -H 'Content-Type: application/json' \
  -d '{"text": "Hello from your agent!"}'
```

**Parameters (JSON body):**

| Field          | Type   | Required | Description                                      |
|----------------|--------|----------|--------------------------------------------------|
| `text`         | string | yes      | The text to speak (max 50,000 characters)        |
| `voice`        | string | no       | Voice name for the active engine (e.g. OpenAI: alloy, echo, fable, onyx, nova, shimmer) |
| `rate`         | number | no       | Speech rate multiplier (e.g. 1.5 for faster)     |
| `instructions` | string | no       | Natural language speaking style (e.g. "Read warmly", "Sound excited"). Only works with OpenAI voices. |
| `engine`       | string | no       | Override the engine for this read: `apple`, `openai`, or `elevenlabs`. Defaults to the app's configured engine. ElevenLabs gives the tightest word-highlight sync (server-side character timestamps). |
| `project_id`   | string | no       | Stable identifier for the calling project (recommend the working directory). VoxClaw assigns a distinct voice per project and groups overlay indicators by it. |
| `agent_id`     | string | no       | Stable identifier for the agent/session. Combined with `project_id`, gives each concurrent agent its own voice, and scopes "stop reading" so prompting one agent never cuts off another. |

**Plain text** also works:

```bash
curl -X POST http://<mac-ip>:4140/read -d 'Hello from your agent!'
```

**Response:**

```json
{"status": "reading"}
```

### Stop Reading (Ack)

Stop reading the response you previously sent — scoped to a single agent by
`project_id` + `agent_id`, so other agents keep speaking. Useful when the user
sends your agent a new prompt and the old spoken response is now stale.

```bash
curl -X POST http://<mac-ip>:4140/ack \
  -H 'Content-Type: application/json' \
  -d '{"project_id": "/path/to/repo", "agent_id": "session-123"}'
```

| Field        | Type   | Required | Description |
|--------------|--------|----------|-------------|
| `project_id` | string | **yes**  | Same identifier you passed to `/read` (a request without it returns 400) |
| `agent_id`   | string | no       | Same identifier you passed to `/read`; scopes the stop to this one agent. Omit it to stop everything for the project |

The ack stops local playback and is relayed to your LAN peer speakers so it
stops there too. Response: `{"status":"acknowledged"}`.

### Agent Notifications

Use agent notifications for task summaries, failures, and optional live progress updates.

```bash
curl -X POST http://<mac-ip>:4140/agent-notify \
  -H 'Content-Type: application/json' \
  -d '{"kind":"summary","text":"Task complete. I updated the parser and the focused tests passed."}'
```

**Parameters (JSON body):**

| Field          | Type   | Required | Description |
|----------------|--------|----------|-------------|
| `kind`         | string | yes      | `summary`, `progress`, or `failure` |
| `text`         | string | yes      | Spoken text |
| `source`       | string | no       | Agent/source label |
| `voice`        | string | no       | OpenAI voice override |
| `rate`         | number | no       | Speech rate multiplier |
| `instructions` | string | no       | Natural-language speaking style |

Expected response:

```json
{"status":"reading"}
```

or

```json
{"status":"suppressed"}
```

### Check Status

```bash
curl http://<mac-ip>:4140/status
```

**Response:**

```json
{
  "status": "ok",
  "service": "VoxClaw",
  "reading": true,
  "state": "playing",
  "word_count": 42,
  "website": "https://voxclaw.com/",
  "skill_doc": "https://github.com/malpern/VoxClaw/blob/main/SKILL.md",
  "discovery": "_voxclaw._tcp",
  "speak_url": "http://192.168.1.50:4140/read",
  "health_url": "http://192.168.1.50:4140/status",
  "agent_notify_url": "http://192.168.1.50:4140/agent-notify",
  "agent_speech_mode": "summary",
  "agent_speech_verbosity": "brief"
}
```

States: `idle`, `loading`, `playing`, `paused`, `finished`.

`agent_speech_mode` controls what the app will actually speak:

- `off`: speak nothing
- `summary`: speak final summaries and failures
- `live`: speak summaries, failures, and progress updates

## Setup

The user installs VoxClaw on their Mac:

1. Download from [GitHub Releases](https://github.com/malpern/VoxClaw/releases/latest/download/VoxClaw.zip)
2. Move to Applications, launch once to complete onboarding
3. Enable "Network Listener" in Settings (or launch with `voxclaw --listen`)

The listener binds to all interfaces on port 4140 by default. The port is configurable in Settings or via `--port`.

**OpenAI API key is optional.** Without a key, VoxClaw uses Apple's built-in voices. With a key, it uses OpenAI's neural voices (the user provides their own key during onboarding or in Settings).

## Discovery

VoxClaw advertises itself via Bonjour as `_voxclaw._tcp` on the local network. Agents can discover it without knowing the IP address.

## Errors

| Status | Meaning                                    |
|--------|--------------------------------------------|
| 200    | Text accepted, now reading                 |
| 200    | Agent notification accepted or suppressed  |
| 400    | Missing or empty text, or text too long    |
| 404    | Unknown endpoint (use `POST /read`, `POST /agent-notify`, `POST /ack`, or `GET /status`) |
| 413    | Request body too large (max 1 MB)          |

Error responses are JSON: `{"error": "description"}`.

**CORS:** The HTTP API allows requests from `http://localhost` only. For cross-machine access, use `curl` or any HTTP client directly (CORS only applies to browsers).

## Examples

**Speak a summary after a task completes:**

```bash
curl -X POST http://192.168.1.50:4140/agent-notify \
  -H 'Content-Type: application/json' \
  -d '{"kind":"summary","text":"Task complete. I deployed the new version and all tests passed."}'
```

**Use a specific voice at faster speed:**

```bash
curl -X POST http://192.168.1.50:4140/agent-notify \
  -H 'Content-Type: application/json' \
  -d '{"kind":"failure","text":"Heads up, the build failed on CI.","voice":"nova","rate":1.3}'
```

**Control speaking style with instructions:**

```bash
curl -X POST http://192.168.1.50:4140/read \
  -H 'Content-Type: application/json' \
  -d '{"text": "Welcome back! Your deploy succeeded.", "instructions": "Read warmly and conversationally"}'
```

**Check if VoxClaw is available before sending:**

```bash
curl -s http://192.168.1.50:4140/status | grep -q '"status":"ok"' && \
  curl -X POST http://192.168.1.50:4140/agent-notify \
    -H 'Content-Type: application/json' \
    -d '{"kind":"summary","text":"Ready to go."}'
```
