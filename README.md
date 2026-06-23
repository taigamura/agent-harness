# Voice to Claude — Local Whisper Dictation

Push-to-talk dictation for bilingual (JP/EN) input into Claude Code and any Windows text field. Runs entirely offline using `whisper.cpp` — no cloud STT, no subscription, no telemetry.

Spec: [[Voice to Claude — Local Whisper Dictation]] in the Obsidian vault.

## How it works

1. Hold **Right Alt** — `ffmpeg` starts capturing 16kHz mono from the default mic.
2. Release Right Alt — `ffmpeg` stops, `whisper-cli` transcribes, the text is pasted into whatever window has focus.
3. Tray tooltip shows state: `idle` / `● RECORDING` / `… transcribing`.

## Layout

```
voice-to-claude/
├── start.bat              ← launch the AHK daemon
├── stop.bat               ← stop only the voice-to-claude AHK instance
├── scripts/
│   ├── voice-to-claude.ahk  ← hotkey + paste glue
│   ├── transcribe.ps1       ← whisper-cli wrapper, cleans output
│   ├── record-test.ps1      ← mic + STT smoke test
│   └── setup.ps1            ← downloads whisper.cpp + model
├── bin/Release/           ← whisper-cli.exe, ffmpeg.exe, dlls (gitignored)
├── models/                ← ggml-*.bin (gitignored, ~140MB-1.6GB each)
└── tmp/                   ← WAV scratch (gitignored)
```

## Setup on a fresh machine

```powershell
# 1. AutoHotkey v2
winget install -e --id AutoHotkey.AutoHotkey

# 2. ffmpeg (winget can fail with "Access is denied"; if so grab the zip
#    from https://www.gyan.dev/ffmpeg/builds/ and copy ffmpeg.exe to bin\Release\)
winget install -e --id Gyan.FFmpeg

# 3. whisper.cpp + base model (~140MB)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\setup.ps1 -Model base

# 4. Verify mic capture and STT end-to-end
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\record-test.ps1

# 5. Start the daemon
.\start.bat
```

## Models

| Model | Size | Latency on Intel Xe (11s clip) | JP quality |
|---|---|---|---|
| `base` | 142 MB | **2.2 s** | adequate (default) |
| `small` | 466 MB | 5.9 s | better |
| `large-v3-turbo` | 1.6 GB | 36 s | best, but slow |

Swap the model by re-running setup: `scripts\setup.ps1 -Model small`. Then point `transcribe.ps1` at it via `-ModelPath`, or edit the default in the script.

## Hotkey

Default is **Right Alt**, push-to-talk. Change in `scripts\voice-to-claude.ahk`:

```ahk
*RAlt::          ; <- replace RAlt with desired key
*RAlt up::       ; <- and here
```

Also bound:
- `Ctrl+Alt+Shift+R` — reload script
- `Ctrl+Alt+Shift+Q` — quit

## Microphone

Default device is the laptop's Intel array, hardcoded by **DirectShow alternative name** (a GUID, immune to character-encoding issues). To use a different mic:

```powershell
.\bin\Release\ffmpeg.exe -hide_banner -f dshow -list_devices true -i dummy
```

Find your device, copy its **`Alternative name`** line (looks like `@device_cm_{GUID}\wave_{GUID}`) — NOT the friendly name on the line above. Friendly names contain characters like `®` that get mangled passing through AHK → ffmpeg and silently produce 0-byte WAVs.

Update `DshowDevice` near the top of `scripts\voice-to-claude.ahk`.

## Autostart on login

Put a shortcut to `start.bat` in `shell:startup`:

```
Win+R → shell:startup → paste shortcut
```

## Known limits

- Cold model load on first invocation adds ~1s. Subsequent invocations are still cold because we re-spawn whisper-cli each time. A persistent `whisper-server` mode is on the v2 roadmap.
- `large-v3-turbo` is too slow for hotkey latency on CPU-only hardware. Use `base` or `small`.
- Hallucinated phrases on silence (e.g. "ご視聴ありがとうございました") are mostly mitigated by `--suppress-nst`. For aggressive silence, enable VAD by downloading `ggml-silero-v5.1.2.bin` into `models/` and adding `--vad --vad-model models\ggml-silero-v5.1.2.bin` to `transcribe.ps1`.

## Not in scope (v1)

Wake-word activation, speaker diarization, streaming interim hypotheses, custom SAP vocab biasing, cross-platform support.
