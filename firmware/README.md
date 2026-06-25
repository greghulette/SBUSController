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
  pair: commit both or neither. (Both are committed here once; you only update
  the app + part each build — though re-committing an unchanged part is fine.)
- The bootloader is the **custom short-watchdog 16 MB** build (cold-boot
  auto-retry) — the matched pair of the firmware's in-app boot guard. Do **not**
  replace it with the stock Arduino IDE bootloader. It's kept under a fixed name
  so a stray stock `*_boot.bin` can never shadow it.

## Building the app + partition binaries

Build the sketch for the SBUSController board options
(`USBMode=hwcdc, CDCOnBoot=cdc, PartitionScheme=min_spiffs`, 16 MB), then drop
the compiled `*_ESP32S3.bin` and `*_ESP32S3_part.bin` here and commit. Use
whatever export flow you already use for NaviCore / RC-Controller (e.g.
ESP-Flasher-Companion or `arduino-cli compile --output-dir`).

## Flash modes (in the config tool)

- **Update** — writes bootloader + partitions + app, **preserves** saved config (NVS).
- **Full Wipe & Flash** — same, plus erases NVS (`0x9000`) and OTA data
  (`0xE000`) for a factory-fresh board / recovery.

A blank board needs the full set (all three) at least once; thereafter Update is
enough.
