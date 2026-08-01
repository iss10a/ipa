#!/usr/bin/env bash
#
# Produces an UNSIGNED .ipa for later signing by an external service.
#
# `flutter build ipa` cannot be used: its export step always requires a signing
# identity and an export options plist. Instead the .app is built with signing
# disabled and packaged into the Payload/ layout that defines an .ipa.
#
# The output is NOT installable as-is. It must be re-signed before it will run
# on a device.
#
# Usage:  BUNDLE_ID=com.example.app bash tool/build_unsigned_ipa.sh

set -euo pipefail

BUILD_NAME="${BUILD_NAME:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
OUTPUT_DIR="${OUTPUT_DIR:-build/ios/ipa}"
IPA_NAME="${IPA_NAME:-pvo-unsigned.ipa}"
APP_PATH="build/ios/iphoneos/Runner.app"

echo "==> Cleaning previous artefacts"
rm -rf "$OUTPUT_DIR" Payload

echo "==> Building release .app without code signing"
flutter build ios \
  --release \
  --no-codesign \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER"

if [ ! -d "$APP_PATH" ]; then
  echo "error: $APP_PATH was not produced. Check the build output above." >&2
  exit 1
fi

echo "==> Packaging Payload/Runner.app into an .ipa"
mkdir -p Payload
cp -R "$APP_PATH" Payload/

# Any residual signature confuses most signing services.
rm -rf Payload/Runner.app/_CodeSignature
rm -f  Payload/Runner.app/embedded.mobileprovision

mkdir -p "$OUTPUT_DIR"
# -y preserves the symlinks inside embedded frameworks. Without it the archive
# is rejected by signing tools and by iOS itself.
zip -qry "$OUTPUT_DIR/$IPA_NAME" Payload
rm -rf Payload

SIZE=$(du -h "$OUTPUT_DIR/$IPA_NAME" | cut -f1)
echo
echo "==> Done"
echo "    File:   $OUTPUT_DIR/$IPA_NAME"
echo "    Size:   $SIZE"
echo "    Signed: NO - sign this before installing."
