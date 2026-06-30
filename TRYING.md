# Trying Bedtime Books

This is a native **iOS app**, so you need a **Mac with Xcode 15 or newer** to run
it. The fastest path uses Apple's built-in voice (no model download, no extra
build steps) and gets you to playback in about 10 minutes.

---

## 1. Prerequisites

- macOS with **Xcode 15+** (free from the Mac App Store).
- **XcodeGen** to generate the project file:
  ```bash
  brew install xcodegen
  ```

## 2. Get the code and generate the project

```bash
git clone <your-repo-url>
cd hello-world
git checkout claude/kids-sleep-audio-app-2dr584
xcodegen generate
open BedtimeBooks.xcodeproj
```

`xcodegen generate` creates `BedtimeBooks.xcodeproj` from `project.yml`. The
`.xcodeproj` is intentionally not committed — regenerate it any time.

## 3. Run on the simulator

1. In Xcode's toolbar, pick a simulator (e.g. **iPhone 15**). The simulator
   needs no Apple Developer account or signing.
2. Press **▶ Run** (⌘R). The app launches in a dim, bedtime-friendly dark theme.

## 4. Try the full loop

1. Tap **+** (top right) → **import a document**.
   - Quickest: drag `Samples/the-sleepy-little-star.md` from Finder onto the
     simulator window first, then pick it in the import sheet.
   - Any `.txt`, `.md`, `.pdf`, `.epub`, or `.docx` works too.
2. A **conversion screen** shows progress as the text is read into audio.
3. When it finishes, tap the book → the **player** opens.
4. Try:
   - **Play / pause**, the **scrubber**, and **±15s**.
   - **Sleep timer** (moon icon) — pick a few minutes and watch it fade out.
   - **Speed** (speedometer) and the **chapter list**.
5. Background it / lock the simulator (⌘L) to see **lock-screen controls**.

That's the whole experience using the system voice.

## 5. (Optional, later) Higher-quality neural voice

The natural-sounding Kokoro voice needs a one-time framework build on your Mac
plus a hosted model file — skip this for a first look. When you're ready:

1. Build the on-device TTS frameworks:
   ```bash
   ./Scripts/build_sherpa_xcframework.sh
   ```
   It prints the exact lines to uncomment in `project.yml`
   (`Vendor/SherpaOnnx.swift`, the two frameworks, and
   `SWIFT_ACTIVE_COMPILATION_CONDITIONS: SHERPA_ENABLED`).
2. Host a `.zip` of the Kokoro model files (`model.onnx`, `voices.bin`,
   `tokens.txt`, `espeak-ng-data/`) and put its URL in
   `BedtimeBooks/Resources/voices.json` (the `resourceReference` placeholder).
3. `xcodegen generate` again, run on a **device**, pick the Kokoro voice in
   **Settings → Reading voice**, let it download once, then convert a book.

## 6. Verify the logic without launching the app

The platform-independent parsing/chunking logic has unit tests:

```bash
cd Core && swift test
```

---

## Troubleshooting

- **"No such module 'ZIPFoundation'"** — let Xcode finish *Resolving Package
  Versions* (first open downloads SPM dependencies), then build again.
- **A build error in a Swift file** — this scaffold was written without a Swift
  compiler in the loop, so the first build may need a small tweak. Send the
  exact error and file/line and it can be fixed quickly.
- **Import sheet won't accept a file** — make sure the file is actually on the
  simulator's Files app (drag it onto the simulator first), or try a `.txt`.
- **No sound** — check the simulator isn't muted (Hardware → Audio) and the Mac
  volume is up.
