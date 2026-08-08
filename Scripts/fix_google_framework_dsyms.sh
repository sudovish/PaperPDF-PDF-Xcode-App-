#!/bin/sh

set -euo pipefail

if [ -z "${ARCHIVE_PATH:-}" ]; then
  exit 0
fi

APP_PATH="$ARCHIVE_PATH/Products/Applications/Paper PDF.app"
if [ ! -d "$APP_PATH/Frameworks" ]; then
  exit 0
fi

generate_framework_dsym() {
  framework_name="$1"
  bin="$APP_PATH/Frameworks/$framework_name.framework/$framework_name"
  out="$ARCHIVE_PATH/dSYMs/$framework_name.framework.dSYM"
  out_dwarf="$out/Contents/Resources/DWARF/$framework_name"

  if [ ! -f "$bin" ]; then
    echo "[dSYM Fix] Skipping $framework_name because the framework binary was not found."
    return 0
  fi

  if [ ! -f "$out_dwarf" ]; then
    mkdir -p "$ARCHIVE_PATH/dSYMs"
    rm -rf "$out"
    xcrun dsymutil "$bin" -o "$out"
  fi

  if [ ! -f "$out_dwarf" ]; then
    echo "[dSYM Fix] Failed to generate $framework_name.framework.dSYM."
    exit 1
  fi

  bin_uuids="$(xcrun dwarfdump --uuid "$bin" | awk '{print $2}' | sort)"
  dsym_uuids="$(xcrun dwarfdump --uuid "$out_dwarf" | awk '{print $2}' | sort)"

  if [ "$bin_uuids" != "$dsym_uuids" ]; then
    echo "[dSYM Fix] UUID mismatch for $framework_name."
    echo "  Binary UUIDs: $bin_uuids"
    echo "  dSYM UUIDs:   $dsym_uuids"
    exit 1
  fi

  echo "[dSYM Fix] Generated matching dSYM for $framework_name."
}

generate_framework_dsym "GoogleMobileAds"
generate_framework_dsym "UserMessagingPlatform"
