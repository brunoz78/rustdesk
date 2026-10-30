#!/usr/bin/env bash
# Bakes the Fernwartung settings into the RustDesk sources before the build.
# Every replacement is checked, so an upstream change breaks the build loudly
# instead of silently producing a stock RustDesk client.
set -euo pipefail

cd "$(dirname "$0")/.."
source fernwartung/settings.env

replace() {
  local file="$1" from="$2" to="$3"
  if ! grep -qF -- "$from" "$file"; then
    echo "::error file=$file::pattern not found: $from"
    exit 1
  fi
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$file"
  echo "patched $file: $from"
}

# Server, key and API server
replace libs/hbb_common/src/config.rs '"rs-ny.rustdesk.com"' "\"$RENDEZVOUS_SERVER\""
replace libs/hbb_common/src/config.rs 'OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw=' "$RS_PUB_KEY"
replace src/common.rs '"https://admin.rustdesk.com".to_owned()' "\"$API_SERVER\".to_owned()"

# Application name used at runtime (window title, config folder, service, install path)
replace libs/hbb_common/src/config.rs 'RwLock::new("RustDesk".to_owned())' "RwLock::new(\"$APP_NAME\".to_owned())"

# File properties of the executables
for f in Cargo.toml libs/portable/Cargo.toml; do
  replace "$f" 'ProductName = "RustDesk"' "ProductName = \"$APP_NAME\""
  replace "$f" 'FileDescription = "RustDesk Remote Desktop"' "FileDescription = \"$APP_NAME\""
  replace "$f" 'OriginalFilename = "rustdesk.exe"' "OriginalFilename = \"$EXE_NAME.exe\""
  replace "$f" 'Purslane Tech Pte. Ltd.' "$COMPANY_NAME"
done
rc=flutter/windows/runner/Runner.rc
replace "$rc" '"Purslane Tech Pte. Ltd."' "\"$COMPANY_NAME\""
replace "$rc" 'Purslane Tech Pte. Ltd.' "$COMPANY_NAME"
replace "$rc" '"RustDesk Remote Desktop"' "\"$APP_NAME\""
replace "$rc" 'VALUE "InternalName", "rustdesk"' "VALUE \"InternalName\", \"$EXE_NAME\""
replace "$rc" '"rustdesk.exe"' "\"$EXE_NAME.exe\""
replace "$rc" 'VALUE "ProductName", "RustDesk"' "VALUE \"ProductName\", \"$APP_NAME\""

# Optional own logo: fernwartung/icon.png (square, 256x256 or larger)
if [ -f fernwartung/icon.png ]; then
  cp fernwartung/icon.png res/icon.png
  magick res/icon.png -define icon:auto-resize=256,128,96,64,48,40,32,24,20,16 res/icon.ico
  magick res/icon.png -resize 32x32 res/tray-icon.ico
  magick res/icon.png -resize 32x32 res/32x32.png
  magick res/icon.png -resize 64x64 res/64x64.png
  magick res/icon.png -resize 128x128 res/128x128.png
  magick res/icon.png -resize 256x256 res/128x128@2x.png
  cp res/icon.ico flutter/windows/runner/resources/app_icon.ico
  echo "own logo applied"
fi

echo "Fernwartung settings applied: $APP_NAME -> $RENDEZVOUS_SERVER"
