# Vox Mac (Command Tracker)

A 100% offline, privacy-first, zero-latency macOS Daemon that uses Apple's native Neural Engine to listen and convert speech into high-speed interface commands (Open Safari, Close Windows, Pause Music, Control Audio).

## Features
- **Total Local Processing:** Uses `requiresOnDeviceRecognition = true`, ensuring no audio is ever sent to Apple's AI or the internet.
- **StandBy Listening:** Acts natively in background without pressing buttons or interrupting music playback.
- **Dynamic Configuration:** Uses `commands.json` to bind voice triggers to macOS app launching, AppleScript actions, and global Hardware Media Keys (Volume/Playback).
- **Native Security Immunity:** Automates Apple Event allowances (bypassing strict macOS App Sandboxing rules) using custom `codesign` injections and entitlement files.

## How to Build & Install
Run the automated build script:
```bash
./build.sh
```
This script cleanly compiles the Swift source (`swiftc`) into a native macOS `.app` bundle, parses the raw `icon_vox.svg` to an Apple `AppIcon.icns` vector dictionary via `sips`, securely signs the code to allow for system accessibility overrides, and clears OS permission caches to prompt automation.

## Project Structure
- `commands.json`: Mapping dictionary of word triggers to actions.
- `Sources/VoiceController.swift`: On-device `AVAudioEngine` pipeline and `SFSpeechRecognizer` loop.
- `Sources/ActionHandler.swift`: Global App quit/launch, Safari URL management, and CGEvent media keys handler.
- `build.sh`: Orchestrator script.
