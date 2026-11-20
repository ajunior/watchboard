#!/usr/bin/env bash
# package-library.sh — Zip the Arduino library for "Add .ZIP Library…".
# Run from the project root. Writes dist/WatchBoard-library-<version>.zip with a
# single WatchBoard/ folder at the top, which is the layout the Arduino IDE and
# arduino-cli (`lib install --zip-path`) both expect.
set -euo pipefail

VERSION=$(sed -n 's/^project(.* VERSION \([0-9][0-9.]*\).*/\1/p' CMakeLists.txt | head -1)
LIB_VERSION=$(sed -n 's/^version=//p' firmware/WatchBoard/library.properties | tr -d '\r')
DIST="$(pwd)/dist"
ZIP="$DIST/WatchBoard-library-${VERSION}.zip"

# The app and the library speak one protocol and ship as one release, so a
# library.properties left behind on a version bump is a release bug.
if [[ "$LIB_VERSION" != "$VERSION" ]]; then
    echo "error: library.properties says $LIB_VERSION, CMakeLists.txt says $VERSION" >&2
    exit 1
fi

mkdir -p "$DIST"
rm -f "$ZIP"
# Only what git tracks: no build/ folders from local compiles, no editor files.
STAGE="$(mktemp -d)"
git archive --format=tar HEAD firmware/WatchBoard | tar -x -C "$STAGE"
(cd "$STAGE/firmware" && zip -qr -X "$ZIP" WatchBoard)
rm -rf "$STAGE"

unzip -l "$ZIP"
echo "Library zip created: $ZIP"
