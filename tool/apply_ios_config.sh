#!/usr/bin/env bash
#
# Applies tool/app_config.env to the generated Xcode project and
# forces code signing off in every build configuration.
#
# Why rewrite project.pbxproj instead of relying on the xcconfig alone:
# target-level build settings stored in the pbxproj take precedence over an
# xcconfig, so PRODUCT_BUNDLE_IDENTIFIER has to be changed in the project file
# itself. The xcconfig stays as the single human-editable source of truth.
#
# Idempotent. Works with both GNU sed (Linux) and BSD sed (macOS).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PBXPROJ="$ROOT/ios/Runner.xcodeproj/project.pbxproj"
CONFIG="$ROOT/tool/app_config.env"

if [ ! -f "$PBXPROJ" ]; then
  echo "error: $PBXPROJ not found." >&2
  echo "Run 'flutter create --platforms=ios .' first." >&2
  exit 1
fi

read_setting() {
  grep -E "^[[:space:]]*$1[[:space:]]*=" "$CONFIG" | head -1 | cut -d'=' -f2- | xargs
}

# An explicit BUNDLE_ID in the environment wins, so CI can override without
# committing a change to the xcconfig.
BUNDLE_ID="${BUNDLE_ID:-$(read_setting APP_BUNDLE_ID)}"

if [ -z "$BUNDLE_ID" ]; then
  echo "error: APP_BUNDLE_ID is empty in $XCCONFIG and \$BUNDLE_ID is unset" >&2
  exit 1
fi

if sed --version >/dev/null 2>&1; then
  SED_INPLACE=(-i)
else
  SED_INPLACE=(-i '')
fi

echo "==> Bundle identifier: $BUNDLE_ID"

# The RunnerTests target uses "<id>.RunnerTests". sed has no negative lookahead,
# so park that value behind a placeholder, rewrite everything else, then restore
# it. This keeps the two targets from collapsing onto the same identifier.
# The placeholder must not contain the key name, otherwise the general pass
# below matches it too and the test target loses its suffix.
sed "${SED_INPLACE[@]}" -E \
  "s/PRODUCT_BUNDLE_IDENTIFIER = [^;]*\.RunnerTests;/__TESTS_BUNDLE_ID__;/g" \
  "$PBXPROJ"

sed "${SED_INPLACE[@]}" -E \
  "s/PRODUCT_BUNDLE_IDENTIFIER = [^;]*;/PRODUCT_BUNDLE_IDENTIFIER = ${BUNDLE_ID};/g" \
  "$PBXPROJ"

sed "${SED_INPLACE[@]}" -E \
  "s/__TESTS_BUNDLE_ID__;/PRODUCT_BUNDLE_IDENTIFIER = ${BUNDLE_ID}.RunnerTests;/g" \
  "$PBXPROJ"

echo "==> Removing every Apple account reference"
sed "${SED_INPLACE[@]}" -E \
  -e 's/DEVELOPMENT_TEAM = [^;]*;//g' \
  -e 's/DevelopmentTeam = [^;]*;//g' \
  -e 's/PROVISIONING_PROFILE_SPECIFIER = [^;]*;//g' \
  -e 's/PROVISIONING_PROFILE = [^;]*;//g' \
  "$PBXPROJ"

echo "==> Clearing any pinned signing identity"
# CODE_SIGN_STYLE is deliberately left as-is. Switching it to Manual makes
# xcodebuild demand a provisioning profile, which is exactly what an unsigned
# build does not have.
sed "${SED_INPLACE[@]}" -E \
  -e 's/CODE_SIGN_IDENTITY = "[^"]*";/CODE_SIGN_IDENTITY = "";/g' \
  "$PBXPROJ"

# --- verification ------------------------------------------------------------
TEAMS=$(grep -c "DEVELOPMENT_TEAM" "$PBXPROJ" || true)
PROFILES=$(grep -c "PROVISIONING_PROFILE" "$PBXPROJ" || true)
IDS=$(grep -c "PRODUCT_BUNDLE_IDENTIFIER = ${BUNDLE_ID};" "$PBXPROJ" || true)
TEST_IDS=$(grep -c "PRODUCT_BUNDLE_IDENTIFIER = ${BUNDLE_ID}.RunnerTests;" "$PBXPROJ" || true)

echo
echo "    app configurations using $BUNDLE_ID   : $IDS"
echo "    test configurations (.RunnerTests)    : $TEST_IDS"
echo "    DEVELOPMENT_TEAM entries remaining    : $TEAMS"
echo "    PROVISIONING_PROFILE entries remaining: $PROFILES"

if [ "$TEAMS" -ne 0 ] || [ "$PROFILES" -ne 0 ]; then
  echo "error: signing references survived the rewrite" >&2
  exit 1
fi
echo "==> Project is clean of Apple account data."
