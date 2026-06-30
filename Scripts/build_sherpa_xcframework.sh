#!/usr/bin/env bash
#
# build_sherpa_xcframework.sh — build the on-device neural TTS frameworks.
#
# sherpa-onnx does not publish a ready-made Swift Package / xcframework, so we
# build it once on a Mac and vendor the output under ./Vendor. Run this on
# macOS with Xcode command-line tools installed, then uncomment the
# `framework:` dependencies in project.yml and run `xcodegen generate`.
#
# Usage:  ./Scripts/build_sherpa_xcframework.sh
#
set -euo pipefail

SHERPA_TAG="${SHERPA_TAG:-v1.13.3}"   # pin to a known-good release
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/Vendor"
WORK_DIR="$(mktemp -d)"

echo "==> Building sherpa-onnx $SHERPA_TAG for iOS"
echo "    work dir: $WORK_DIR"
echo "    output:   $VENDOR_DIR"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "ERROR: this build must run on macOS with Xcode." >&2
  exit 1
fi

git clone --depth 1 --branch "$SHERPA_TAG" https://github.com/k2-fsa/sherpa-onnx "$WORK_DIR/sherpa-onnx"
cd "$WORK_DIR/sherpa-onnx"

# sherpa-onnx ships iOS build scripts that produce the xcframeworks.
# (Names match the repo at the pinned tag; adjust if the repo layout changes.)
./build-ios.sh

mkdir -p "$VENDOR_DIR"
# Copy the produced xcframeworks into Vendor/.
find build-ios -name "*.xcframework" -maxdepth 3 -exec cp -R {} "$VENDOR_DIR/" \;

echo "==> Done. Vendored:"
ls -1 "$VENDOR_DIR"
echo
echo "Next: uncomment the sherpa-onnx / onnxruntime framework dependencies in"
echo "project.yml, then run: xcodegen generate"
