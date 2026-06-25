#!/usr/bin/env python3
"""
sync_html.py — regenerate docs/index.html from SBUSController_html.h.

SBUSController_html.h is the canonical source: the firmware embeds its
contents (between the R"rawhtml( ... )rawhtml" delimiters) into flash and
serves them from the ESP32's web server.  GitHub Pages can't read C headers,
so we mirror the same HTML body into docs/index.html for the static / USB
Serial workflow.

Run this whenever you edit SBUSController_html.h:

    python sync_html.py

It extracts the raw-string body and writes it to docs/index.html, with ONE
substitution: the `__UI_VERSION__` token is replaced with a WCB-style DTG
build stamp so the page footer shows a UI version that tracks every deploy.
The canonical .h keeps the literal token, so the ESP-served WiFi copy falls
back to "dev" (the token is never replaced there). Both the .h and
docs/index.html should be checked in to git.
"""
from pathlib import Path
import datetime
import sys

HERE = Path(__file__).resolve().parent
SRC  = HERE / "SBUSController_html.h"
DST  = HERE / "docs" / "index.html"

START_MARKER = 'R"rawhtml('
END_MARKER   = ')rawhtml";'
VERSION_TOKEN = "__UI_VERSION__"

MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
          'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC']


def build_version() -> str:
    """WCB-style DTG stamp: DD.HH:MM.R.MON.YYYY  (e.g. 25.12:33.R.JUN.2026).

    Matches the WCB Config Tool's UI version format exactly. The 'R' is the
    project's fixed zone letter (not DST-computed). Time is US Eastern so the
    clock matches the bench; falls back to a fixed UTC-5 offset if the tz
    database isn't present (e.g. bare Windows without tzdata)."""
    try:
        from zoneinfo import ZoneInfo
        now = datetime.datetime.now(ZoneInfo("America/New_York"))
    except Exception:
        now = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=5)
    return (f"{now.day:02d}.{now.hour:02d}:{now.minute:02d}"
            f".R.{MONTHS[now.month - 1]}.{now.year}")


def main() -> int:
    if not SRC.exists():
        print(f"error: source not found: {SRC}", file=sys.stderr)
        return 1

    text = SRC.read_text(encoding="utf-8")
    start = text.find(START_MARKER)
    if start < 0:
        print(f"error: opening marker {START_MARKER!r} not found in {SRC.name}",
              file=sys.stderr)
        return 1
    body_start = start + len(START_MARKER)
    body_end   = text.find(END_MARKER, body_start)
    if body_end < 0:
        print(f"error: closing marker {END_MARKER!r} not found after opening marker",
              file=sys.stderr)
        return 1

    body = text[body_start:body_end]
    # Strip a leading newline if present so the file starts with <!DOCTYPE html>.
    if body.startswith("\n"):
        body = body[1:]

    # Stamp the UI build version into the footer (the only transformation).
    # Replace only the QUOTED JS string literal ('__UI_VERSION__'), not bare
    # mentions of the token in comments.
    version = build_version()
    quoted_old = f"'{VERSION_TOKEN}'"
    quoted_new = f"'{version}'"
    n_subs = body.count(quoted_old)
    body = body.replace(quoted_old, quoted_new)

    DST.parent.mkdir(parents=True, exist_ok=True)
    DST.write_text(body, encoding="utf-8", newline="\n")

    lines = body.count("\n") + (0 if body.endswith("\n") else 1)
    print(f"wrote {DST}  ({len(body):,} bytes, {lines:,} lines)")
    print(f"  UI version: {version}  ({n_subs} substitution{'' if n_subs == 1 else 's'})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
