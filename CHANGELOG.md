# Changelog

## 0.44.11

First public release.

### App

- Ready-made builds: an AppImage for Linux, a DMG for macOS 13 or later and an installer for 64-bit Windows.
- Four tabs: **Home** (board, port and system info), **Pins** (digital and analog pins, with output toggles), **Variables** (table and 30-second plot) and **Serial** (raw traffic, with sending and saving).
- Pin labels saved in per-sketch profiles; light and dark theme (<kbd>Ctrl</kbd>+<kbd>D</kbd>); `--port` to connect on startup.

### Arduino library

- Released as `WatchBoard-library-0.44.11.zip`, ready for *Add .ZIP Library…*. Supports AVR, SAMD, ESP32 and ESP8266.
- Output pins are reported as `OUTPUT` on every supported architecture, so the app shows a switch for them.
- On ESP32, analog pins are labelled with the board's A name (GPIO36 is `A0`).
- `watch()` values are sent with two decimal places and correct rounding, including negative values; NaN and infinity are sent as `null`.
- Commands from the app are accepted with either `\n` or `\r` line endings, and a line too long for the buffer is dropped instead of being read in pieces.
- A `set` command only changes a pin that is watched and configured as an output.
