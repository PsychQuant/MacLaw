# MacLaw Meet Recorder

## Summary

Add a Google Meet recording capability to MacLaw, using the activation/pipeline system to automatically join meetings and record screen + audio.

## Motivation

- Record online talks/workshops/meetings automatically on the PsychQuantClaw Mac Mini
- Mac Mini is always-on, has GUI session, Chrome, ffmpeg, BlackHole — ideal recording station
- Pipeline concept fits: join → record → stop → notify is a multi-step workflow

## Key Learnings from Manual Testing (2026-03-21)

### What works
1. **ffmpeg screen recording** via `avfoundation` — must run from **GUI Terminal** (SSH doesn't have screen capture permission)
2. **ffmpeg audio recording** via BlackHole 2ch virtual audio device
3. **Playwright** can launch Chrome and interact with pages (click join button)
4. **Chrome with user profile** preserves Google account login

### Critical requirements
1. **GUI Terminal context required** — `screencapture` and `ffmpeg avfoundation` only work when launched from a GUI Terminal session (Terminal.app), not from SSH. Use `osascript → tell Terminal → do script` pattern.
2. **Meet speaker must be set to BlackHole** — macOS system audio output setting is NOT enough. VNC intercepts audio separately. Must set Meet's own speaker setting to "BlackHole 2ch" in Meet → Settings → Audio → Speaker.
3. **Google account login required** — Meet rejects anonymous users with "你無法加入這場視訊通話". Chrome must have a logged-in Google account.
4. **BlackHole needs reboot after install** — `brew install --cask blackhole-2ch` requires sudo + reboot.
5. **Chrome remote debugging port doesn't bind on macOS** — `--remote-debugging-port=9222` flag doesn't work reliably. Use Playwright `connectOverCDP` or `launchPersistentContext` instead.
6. **Playwright `launchPersistentContext` with `channel: 'chrome'` hangs** — use `spawn` + `connectOverCDP` pattern instead.
7. **VNC audio channel is separate** — VNC has its own audio forwarding. User can hear Meet audio through VNC even when system output is BlackHole. This is a feature (user can monitor) not a bug.
8. **Auto-login needed after reboot** — Mac Mini stops at login screen after reboot. Either configure auto-login via `sysadminctl` or keep VNC available for manual login.
9. **Screen Recording permission** — ffmpeg/Terminal needs to be granted Screen & System Audio Recording permission in System Settings → Privacy & Security.

### Audio routing diagram
```
Meet audio → Chrome → macOS audio output
                          ↓
                   System output = BlackHole 2ch (not enough alone)
                   Meet speaker = BlackHole 2ch (THIS is what matters)
                          ↓
                   BlackHole input device
                          ↓
                   ffmpeg -f avfoundation -i ":0" (records from BlackHole)
```

## Proposed Architecture

### Option A: Shell action type in Pipeline (recommended)

Add `ActionType.shell` to the existing pipeline system:

```swift
enum ActionType: String, Codable {
    case task      // existing: send prompt to LLM backend
    case pipeline  // existing: run pipeline
    case shell     // NEW: execute shell command directly
}
```

Pipeline steps can then mix LLM and shell actions:

```json
{
  "id": "record-meet",
  "steps": [
    { "name": "launch-chrome", "type": "shell", "command": "open -na 'Google Chrome' --args '{{meetUrl}}'" },
    { "name": "wait-load", "type": "shell", "command": "sleep 15" },
    { "name": "start-screen", "type": "shell", "command": "ffmpeg -f avfoundation -pixel_format uyvy422 -framerate 5 -i '0:none' -t {{duration}} -c:v libx264 -preset ultrafast -crf 28 -pix_fmt yuv420p -y {{outputDir}}/screen.mp4 &" },
    { "name": "start-audio", "type": "shell", "command": "ffmpeg -f avfoundation -i ':0' -t {{duration}} -c:a aac -b:a 128k -y {{outputDir}}/audio.m4a &" },
    { "name": "wait-duration", "type": "shell", "command": "sleep {{duration}}" },
    { "name": "cleanup", "type": "shell", "command": "killall ffmpeg; osascript -e 'tell application \"Google Chrome\" to quit'" }
  ]
}
```

### Option B: Dedicated MeetRecorder module

A specialized `MeetRecorder` actor that handles the full lifecycle:

```swift
actor MeetRecorder {
    func record(url: String, duration: TimeInterval, outputDir: String) async throws -> RecordingResult
}
```

This encapsulates the complexity (GUI Terminal context, BlackHole setup, Chrome launch, ffmpeg management) but is less flexible than the pipeline approach.

### Recommendation

Start with **Option B** for reliability (the GUI Terminal requirement makes shell-in-pipeline tricky), then expose it as a pipeline action type later.

## Config Example

```json
{
  "activations": [
    {
      "id": "cake-session2",
      "type": "schedule",
      "schedule": "at 2026-03-21T09:48:00+08:00",
      "action": {
        "type": "meet-record",
        "meetUrl": "https://meet.google.com/zav-hfdp-cwn",
        "duration": "75m",
        "outputPrefix": "session2-sdd"
      }
    }
  ]
}
```

## Dependencies

- Google Chrome (installed)
- ffmpeg (`brew install ffmpeg`)
- BlackHole 2ch (`brew install --cask blackhole-2ch`, requires reboot)
- SwitchAudioSource (`brew install switchaudio-osx`)
- GUI session (auto-login or VNC)
- Screen Recording permission for Terminal.app

## Open Questions

1. How to automate "set Meet speaker to BlackHole"? (Currently manual via VNC)
2. How to handle Chrome remote debugging on macOS? (Port binding unreliable)
3. Should MacLaw auto-join Meet or just open Chrome and let user join manually?
4. Timeout handling — what if Meet ends early or ffmpeg crashes?
