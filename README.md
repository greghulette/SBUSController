# SBUS Controller

[**🚀 Launch the config tool →**](https://greghulette.github.io/SBUSController/)

Browser-based virtual SBUS transmitter for the ESP32-S3 (WCB HW 3.2). Drive a
Kyber (or any SBUS receiver) from an on-screen FrSky-style transmitter — 4
joystick axes, 10 switches, sliders, trims, matrix buttons, and 15 configurable
Lua/virtual buttons — over **WiFi** or **USB Serial**.

The on-screen controller is modelled on the FrSky TANDEM X18 / Twin X20 and emits
a standard 16- or 24-channel SBUS stream (100 kbaud 8E2 inverted).

## Two ways to connect

The exact same web UI works over either transport — pick from the **WiFi ▾ /
USB Serial** button in the header.

- **WiFi** — the ESP32 hosts the page itself. Connect to its IP (or the
  `SBUSCtrl` AP fallback) and the page auto-connects over WebSocket.
- **USB Serial** — open the [hosted config tool](https://greghulette.github.io/SBUSController/)
  (or `docs/index.html` locally) in **Chrome or Edge**, click **USB Serial**, and
  pick the board's COM port. No WiFi required — handy when the droid is away from
  a known network. Uses the [Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API);
  no install, no server.

## Flashing firmware from the browser

The config tool has a **Firmware** section (visible on the hosted page over USB
Serial, Chrome/Edge) that flashes the ESP32-S3 with [esptool-js](https://github.com/espressif/esptool-js)
— no Arduino IDE needed for updates.

- **Update** — writes new firmware, keeps your saved config.
- **Full Wipe & Flash** — also erases saved config (factory-fresh / recovery).

If you're already connected over USB Serial it reuses the same port (no second
picker) and auto-reconnects after the board reboots.

Binaries are pulled from [`firmware/`](firmware) on this repo. A GitHub Action
([`.github/workflows/build-firmware.yml`](.github/workflows/build-firmware.yml))
**auto-builds** the app + partition images on every push that changes the sketch
(`.ino`/`.h`) and commits them back to `firmware/` — so the hosted flasher always
serves the latest firmware with no manual build step. The custom short-WDT
bootloader is committed once (fixed name) and left untouched by CI. See
[firmware/README.md](firmware/README.md) for the layout.

> Flashing needs USB Serial. It is unavailable on the ESP-served WiFi page (the
> board doesn't serve `flasher.js`, and esptool needs a direct serial port) —
> use the hosted page over USB.

## Hardware

Target: **ESP32-S3** on a WCB HW 3.2 board.

| Signal | Pin | Notes |
|---|---|---|
| SBUS out | GPIO 9 | Serial5 TX — inverted 100 kbaud 8E2 |
| RC PWM 1–4 | GPIO 4 / 6 / 15 / 17 | mirror selected SBUS channels @ 50 Hz |
| Status LED | GPIO 48 | onboard NeoPixel — red=boot, blue=AP, green=WiFi |
| USB | — | config + debug (WebSocket over WiFi, or Web Serial) |

## Required libraries (Arduino Library Manager)

- `ESPAsyncWebServer` (mathieucarbou fork or me-no-dev)
- `AsyncTCP` (mathieucarbou/AsyncTCP — required for ESP32 core 3.x)
- `ArduinoJson` (Benoit Blanchon) v6.x
- `Adafruit NeoPixel` (status LED)

Board: **esp32 by Espressif (3.x)**.

## Layout

```
SBUSController.ino                       Firmware (single sketch)
SBUSController_html.h                    Canonical web UI — embedded in firmware flash
sync_html.py                             Regenerates docs/index.html from the .h
docs/index.html                          GitHub Pages copy of the web UI (USB-Serial mode)
sbus_config_...(WorkingR2).json          Known-good config — import via the web UI
Layout of Trim and Matrix.svg            Reference: trim + button-matrix wiring
TANDEM-X18-Manual.pdf                    FrSky X18 reference manual
```

## Editing the UI

`SBUSController_html.h` is the **single source of truth** — the firmware embeds
it and serves it over WiFi. `docs/index.html` is a generated mirror for the
GitHub Pages / USB-Serial path. After editing the `.h`, regenerate the docs copy:

```
python sync_html.py
```

Commit **both** files so the WiFi-served page and the hosted page stay in sync.

## GitHub Pages

This repo's config tool is published from the **`/docs` folder on `main`**
(Settings → Pages → Deploy from a branch → `main` / `/docs`). The page works
fully standalone over USB Serial; WiFi mode only applies when the ESP itself is
serving the page.
