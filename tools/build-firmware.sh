#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────
# build-firmware.sh
#
# Compiles SBUSController.ino for the WCB v3.2 hardware (ESP32-S3) and drops
# the build artifacts into firmware/ with versioned names matching the
# suffixes the browser flasher (docs/flasher.js) looks for:
#
#   firmware/SBUSController_<TAG>_ESP32S3.bin        → app image   (0x10000)
#   firmware/SBUSController_<TAG>_ESP32S3_part.bin   → partitions  (0x8000)
#   firmware/SBUSController_<TAG>_ESP32S3_boot.bin   → STOCK bootloader (unused
#       by the flasher — it always uses the committed custom short-WDT
#       WCB_S3_custom_bootloader_16MB_wdt3s.bin instead; kept only for history)
#
# TAG = <UTC date>-<short commit sha>.  The flasher matches purely on the
# filename SUFFIX, so the prefix is just for human traceability — no
# fw_version.h / pre-commit-hook machinery needed.
#
# Used by .github/workflows/build-firmware.yml; also runnable locally on
# macOS / Linux / WSL.  Requirements: arduino-cli on PATH, esp32:esp32 core
# installed, and the libraries the workflow installs.
# ─────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FW_DIR="$REPO_ROOT/firmware"
SKETCH="$REPO_ROOT/SBUSController.ino"

if [ ! -f "$SKETCH" ]; then
  echo "✗ Cannot find SBUSController.ino at $SKETCH" >&2
  exit 1
fi

# ── Version tag — UTC date + short commit sha (no fw_version.h needed) ───
SHA="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo nogit)"
TAG="$(date -u +%Y%m%d)-${SHA}"

# ── Compile ─────────────────────────────────────────────────────────────
# FQBN MUST match the Arduino IDE Tools-menu options used on the bench
# (and the SBUS Controller entry in ESP-Flasher-Companion's
# esp_flasher_config.json):
#   • Board: ESP32S3 Dev Module
#   • USB Mode: Hardware CDC and JTAG          →  USBMode=hwcdc
#   • USB CDC On Boot: Enabled                 →  CDCOnBoot=cdc
#   • Partition Scheme: Minimal SPIFFS         →  PartitionScheme=min_spiffs
# NOTE: NO PSRAM option — SBUSController does not allocate from PSRAM, and the
# bench/flasher config omits it. (NaviCore uses PSRAM=opi because it ps_calloc's
# a large struct; SBUSController does not.) Keep min_spiffs so the partition
# table matches the flasher's assumed layout (nvs 0x9000 / app 0x10000).
FQBN="esp32:esp32:esp32s3:USBMode=hwcdc,CDCOnBoot=cdc,PartitionScheme=min_spiffs"
BUILD_DIR="${TMPDIR:-/tmp}/sbus-fw-build"

echo ""
echo "Building SBUSController firmware"
echo "  tag  : $TAG"
echo "  fqbn : $FQBN"
echo ""

rm -rf "$BUILD_DIR"
mkdir -p "$FW_DIR"

echo "→ arduino-cli compile  (this can take a minute)…"
arduino-cli compile \
  --fqbn "$FQBN" \
  --output-dir "$BUILD_DIR" \
  "$REPO_ROOT"

# ── Locate the artifacts arduino-cli produced ───────────────────────────
APP_SRC="$BUILD_DIR/SBUSController.ino.bin"
BOOT_SRC="$BUILD_DIR/SBUSController.ino.bootloader.bin"
PART_SRC="$BUILD_DIR/SBUSController.ino.partitions.bin"

for f in "$APP_SRC" "$BOOT_SRC" "$PART_SRC"; do
  if [ ! -f "$f" ]; then
    echo "✗ Expected build artifact missing: $f" >&2
    exit 1
  fi
done

# ── Clean older versioned SBUSController bins so firmware/ keeps ONE set ──
# Matches only the versioned app/part/boot names — never the fixed custom
# bootloader (WCB_S3_custom_bootloader_16MB_wdt3s.bin), which is preserved.
find "$FW_DIR" -maxdepth 1 -type f -name 'SBUSController_*_ESP32S3*.bin' -delete 2>/dev/null || true

# ── Copy with versioned names ───────────────────────────────────────────
cp "$APP_SRC"  "$FW_DIR/SBUSController_${TAG}_ESP32S3.bin"
cp "$BOOT_SRC" "$FW_DIR/SBUSController_${TAG}_ESP32S3_boot.bin"
cp "$PART_SRC" "$FW_DIR/SBUSController_${TAG}_ESP32S3_part.bin"

echo ""
echo "✓ Built and staged:"
ls -lh "$FW_DIR"/SBUSController_${TAG}_ESP32S3*.bin

rm -rf "$BUILD_DIR"
