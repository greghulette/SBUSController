# Firmware binaries

The browser flasher (`docs/flasher.js`, exposed via the **Firmware** section of
the [config tool](https://greghulette.github.io/SBUSController/)) fetches the
binaries in this folder over the GitHub Contents API and flashes them to the
ESP32-S3 via Web Serial.

## What goes here

Three files, matched by **stable filename suffix** (the version/date prefix can
be anything — the flasher picks the newest by suffix):

| File (suffix) | Flash address | Source |
|---|---|---|
| `*_ESP32S3.bin` | `0x10000` | application image — **you build this** |
| `*_ESP32S3_part.bin` | `0x8000` | partition table — **you build this** |
| `WCB_S3_custom_bootloader_16MB_wdt3s.bin` | `0x0` | custom short-WDT bootloader — **fixed, already committed** |

- The **app** image is required. The **bootloader + partition table** are a
  pair: commit both or neither.
- The bootloader is the **custom short-watchdog 16 MB** build (cold-boot
  auto-retry) — the matched pair of the firmware's in-app boot guard. Do **not**
  replace it with the stock Arduino IDE bootloader. It's kept under a fixed name
  so a stray stock `*_boot.bin` can never shadow it.

## These are auto-built — you normally don't touch them

`.github/workflows/build-firmware.yml` compiles the sketch on every push that
changes `*.ino` / `*.h` and commits the fresh `*_ESP32S3.bin` +
`*_ESP32S3_part.bin` here (`Auto-build: update firmware binaries [skip ci]`).
The flasher then serves the latest build automatically.

The CI also commits a **stock** `*_ESP32S3_boot.bin` for completeness — the
flasher ignores it and always uses the fixed custom bootloader above.

To build locally instead (macOS/Linux/WSL): run `tools/build-firmware.sh`. On
Windows, use the Arduino IDE / ESP-Flasher-Companion with the board options
`USBMode=hwcdc, CDCOnBoot=cdc, PartitionScheme=min_spiffs` (16 MB).

## Flash modes (in the config tool)

- **Update** — writes bootloader + partitions + app, **preserves** saved config (NVS).
- **Full Wipe & Flash** — same, plus erases NVS (`0x9000`) and OTA data
  (`0xE000`) for a factory-fresh board / recovery.

A blank board needs the full set (all three) at least once; thereafter Update is
enough.
