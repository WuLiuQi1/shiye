#!/usr/bin/env bash
# Creates the Flutter-owned Android/iOS host projects and verifies a development build.
# Run from the repository root on a machine with Flutter stable installed.
set -euo pipefail

build_android=true
if [[ "${1:-}" == "--skip-android" ]]; then
  build_android=false
elif [[ $# -gt 0 ]]; then
  echo "Usage: bash tool/bootstrap_native_hosts.sh [--skip-android]" >&2
  exit 2
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter stable is required. Install Flutter, add it to PATH, then run this script again." >&2
  exit 1
fi

flutter --version
flutter pub get

# The app source deliberately lives outside platform directories. Flutter owns
# these generated hosts; regenerate them rather than copying a stale host tree.
flutter create --platforms=android,ios --org com.shiye --project-name reader .

# Give each generated host the product name. Bundle/application identifiers stay
# com.shiye.reader until the owner chooses a registered production identifier.
python3 - <<'PY'
from pathlib import Path

android_manifest = Path("android/app/src/main/AndroidManifest.xml")
if android_manifest.exists():
    text = android_manifest.read_text()
    text = text.replace('android:label="reader"', 'android:label="拾页"')
    android_manifest.write_text(text)

info_plist = Path("ios/Runner/Info.plist")
if info_plist.exists():
    text = info_plist.read_text()
    text = text.replace('<string>$(PRODUCT_NAME)</string>', '<string>拾页</string>')
    info_plist.write_text(text)
PY

python3 tool/configure_document_opening.py

# Flutter creates the native host files above, so formatting may legitimately
# update generated Dart files in a fresh CI checkout. Apply formatting before
# validation instead of treating those generated changes as a build failure.
dart format .
flutter analyze
flutter test

if [[ "$build_android" == true ]]; then
  flutter build apk --debug
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  flutter build ios --release --no-codesign
else
  echo "Skipping iOS build: it requires macOS and Xcode."
fi

if [[ "$build_android" == true ]]; then
  echo "Native hosts are ready. Android APK: build/app/outputs/flutter-apk/app-debug.apk"
else
  echo "Native hosts are ready. Android build was skipped."
fi
