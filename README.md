# Bedtime Books 🌙

A native iOS app that turns ebooks and documents into soothing audiobooks for
kids to listen to at bedtime — using **on-device, open-source neural
text-to-speech** (fully offline, private) with a player tuned for falling
asleep (sleep timer, background playback, lock-screen controls, resume).

> Replaces the original ElevenLabs Python CLI (now archived in [`legacy/`](legacy/)).
> The cloud/closed-API approach was swapped for a native, offline, open-source one.

## Features

- **Import** TXT, Markdown, and PDF today; EPUB and Word (`.docx`) wired for the next milestone.
- **On-device neural TTS** via [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) running [Kokoro-82M](https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX) (Apache-2.0). Works offline once the voice is downloaded.
- **Bedtime player**: sleep timer with gentle fade-out, background + lock-screen playback, playback speed, chapter navigation, and resume-where-you-left-off.
- **Kid-safe & private**: no accounts, no tracking, no data collection — everything happens on the device.

## Architecture

SwiftUI + `@Observable` view models + a service layer, with **SwiftData** for the
library. See [`docs`](#) and the in-repo plan for details. High level:

```
Core/                     Cross-platform logic (Foundation only) + unit tests — runs with `swift test`
BedtimeBooks/
  App/                    Entry point, dependency container, root view
  Features/               Library · Import · Conversion · Player · Settings (SwiftUI + view models)
  Services/
    TTS/                  TextExtractor implementations + TTSEngine
    Conversion/           Text → segments → synthesized per-chapter .m4a (with progress/cancel)
    Player/               AVAudioPlayer playback, sleep timer, now-playing, audio session
    Storage/              Application Support file layout
  Models/                 SwiftData Book / Chapter
  Resources/              voices.json, asset catalog
  Support/                Info.plist (generated), PrivacyInfo.xcprivacy
Vendor/                   sherpa-onnx / onnxruntime xcframeworks (built on Mac)
Scripts/                  build_sherpa_xcframework.sh
```

The text-extraction engines (plain text, Markdown), chunking, file-path math,
and voice-catalog decoding live in the **`BedtimeBooksCore`** Swift package so
they can be unit-tested on any platform without Xcode.

## Building

> Requires a **Mac with Xcode 15+**. The `.xcodeproj` is generated from
> `project.yml` and is not committed.

```bash
# 1. Generate the Xcode project
brew install xcodegen
xcodegen generate

# 2. (M2 / neural voices) Build the on-device TTS frameworks, then uncomment the
#    sherpa-onnx dependencies in project.yml and re-run xcodegen generate.
./Scripts/build_sherpa_xcframework.sh

# 3. Open and run
open BedtimeBooks.xcodeproj
#    Set your signing team, then run on a simulator or device.
```

### Running the cross-platform tests (no Xcode needed)

```bash
cd Core
swift test
```

## Roadmap

- **M1 ✅** End-to-end pipeline with Apple's built-in voice (import → convert → play).
- **M2** Swap in sherpa-onnx + Kokoro neural voice; voice download / On-Demand Resources.
- **M3** EPUB and DOCX extraction with chapter detection.
- **M4** Player polish (artwork, parental gate, richer chapter metadata).
- **M5** App Store readiness (privacy, Kids Category compliance, TestFlight).

## Licensing note

Bedtime Books bundles open-source components — see [`LICENSES/`](LICENSES/). One
open item before App Store submission: **espeak-ng (GPL-3.0)** ships with
sherpa-onnx as the phonemizer; confirm GPL-as-bundled-data is acceptable for a
closed-source release, or configure a model path that avoids it.
