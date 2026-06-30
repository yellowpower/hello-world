# Third-Party Licenses & Attribution

Bedtime Books bundles open-source software and (optionally) neural voice models.
This folder collects their license notices; the in-app **Settings → Credits &
Licenses** screen surfaces the same information to users, as required.

| Component | Purpose | License |
|---|---|---|
| [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) | On-device neural TTS runtime | Apache-2.0 |
| [ONNX Runtime](https://github.com/microsoft/onnxruntime) | Model inference (bundled in sherpa-onnx) | MIT |
| [espeak-ng](https://github.com/espeak-ng/espeak-ng) | Text phonemization data (bundled in sherpa-onnx) | **GPL-3.0** |
| [Kokoro-82M v1.0](https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX) | Default neural voice model | Apache-2.0 |
| [Piper voices](https://github.com/rhasspy/piper) | Optional neural voices | Per-voice MODEL_CARD |
| [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | EPUB/DOCX container reading | MIT |

EPUB/DOCX XML and Markdown are parsed with Foundation's built-in `XMLParser`, so
no HTML/Markdown third-party package is bundled.

## ⚠️ Open legal item before App Store submission

**espeak-ng is GPL-3.0.** It ships with sherpa-onnx as the phonemizer. Confirm
that bundling GPL data in a closed-source App Store binary is acceptable for
your distribution, or configure sherpa-onnx with a model path that avoids the
GPL component, before shipping a paid/closed app. This is the one unresolved
licensing question flagged during planning.

## Per-voice attribution

Each neural voice in `BedtimeBooks/Resources/voices.json` carries `license` and
`attribution` fields that the Credits screen renders. Any Piper voice added must
have its MODEL_CARD license verified and recorded there.
