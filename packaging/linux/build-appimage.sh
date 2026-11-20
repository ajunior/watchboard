#!/usr/bin/env bash
# build-appimage.sh — Build a self-contained AppImage for WatchBoard.
# Run from the project root with Qt's qmake on PATH, after `cmake --build build`.
set -euo pipefail

# Portable on purpose (BSD grep has no -P), the same way the macOS script reads it.
VERSION=$(sed -n 's/^project(.* VERSION \([0-9][0-9.]*\).*/\1/p' CMakeLists.txt | head -1)
APPDIR="$(pwd)/AppDir"
DIST="$(pwd)/dist"
TOOLS="${TOOLS_DIR:-${RUNNER_TEMP:-/tmp}}"

mkdir -p "$DIST"

# ── Tools ────────────────────────────────────────────────────────────────────
LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
PLUGIN_URL="https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage"

fetch() {
    if [[ ! -x "$TOOLS/$1" ]]; then
        curl -fsSL "$2" -o "$TOOLS/$1"
        chmod +x "$TOOLS/$1"
    fi
}
fetch linuxdeploy-x86_64.AppImage "$LINUXDEPLOY_URL"
fetch linuxdeploy-plugin-qt-x86_64.AppImage "$PLUGIN_URL"
# linuxdeploy finds its plugins on PATH by name.
export PATH="$TOOLS:$PATH"

# ── Stage executable, desktop file and icon ───────────────────────────────────
rm -rf "$APPDIR"
install -Dm755 build/watchboard "$APPDIR/usr/bin/watchboard"
install -Dm644 packaging/linux/watchboard.desktop "$APPDIR/usr/share/applications/watchboard.desktop"
# assets/watchboard.png is the 1024px master the macOS icns and the Windows ico
# come from too. The copy is the fallback without ImageMagick.
ICON="$(mktemp -d)/watchboard.png"
{ magick assets/watchboard.png -resize 256x256 "$ICON" || convert assets/watchboard.png -resize 256x256 "$ICON"; } 2>/dev/null \
  || cp assets/watchboard.png "$ICON"
install -Dm644 "$ICON" "$APPDIR/usr/share/icons/hicolor/256x256/apps/watchboard.png"

# ── QML modules ───────────────────────────────────────────────────────────────
# linuxdeploy's Qt plugin deploys no QML module at all unless QML_SOURCES_PATHS
# is set, and the AppImage then dies on its first import. Mahina's sources are
# scanned too: it imports modules (QtQuick.Effects, QtQml.Models, Dialogs) that
# nothing under src/qml does. CMakeCache knows where it is, whether it came
# through FetchContent or from FETCHCONTENT_SOURCE_DIR_MAHINA.
cache_dir() { sed -n "s/^$1:STATIC=//p" build/CMakeCache.txt | head -1; }
MAHINA_SRC="$(cache_dir Mahina_SOURCE_DIR)"
MAHINA_BIN="$(cache_dir Mahina_BINARY_DIR)"
if [[ ! -d "$MAHINA_SRC/qml" || ! -f "$MAHINA_BIN/Mahina/qmldir" ]]; then
    echo "error: Mahina's sources or build not found via build/CMakeCache.txt" >&2
    exit 1
fi
export QML_SOURCES_PATHS="$(pwd)/src/qml:$MAHINA_SRC/qml"
# Mahina is linked statically, so no Qt import path has it and the scanner
# reports `import Mahina` as missing, which is fatal. Its build directory
# resolves the import; the copy that gets deployed from there is removed below.
export QML_MODULES_PATHS="$MAHINA_BIN"

# The offscreen platform plugin is what the smoke test below runs on.
export EXTRA_PLATFORM_PLUGINS="libqoffscreen.so"

# ── linuxdeploy ───────────────────────────────────────────────────────────────
export QMAKE="${QMAKE:-$(command -v qmake6 || command -v qmake)}"
export OUTPUT="$DIST/watchboard-${VERSION}-x86_64.AppImage"
# AppImages need FUSE to self-mount, which containers often lack.
export APPIMAGE_EXTRACT_AND_RUN=1

linuxdeploy-x86_64.AppImage --appdir "$APPDIR" --plugin qt

# The Mahina module is compiled into the binary and served from qrc:/qt/qml,
# which Qt searches first, so the copy on disk would be 6 MB never read.
rm -rf "$APPDIR/usr/qml/Mahina"

linuxdeploy-x86_64.AppImage --appdir "$APPDIR" --output appimage

# ── Start what was just built ─────────────────────────────────────────────────
# Starts the artifact itself, not the build tree, in an empty profile, and
# requires it to still be up five seconds later with no QML errors. Exit 124
# from `timeout` is the good case. Missing QML modules print
# "module ... is not installed" and exit, which is the failure this catches.
echo "── smoke test ──"
SMOKE_HOME="$(mktemp -d)"
mkdir -p "$SMOKE_HOME"/{data,config,cache,run}
chmod 700 "$SMOKE_HOME/run"

set +e
smoke_out=$(XDG_DATA_HOME="$SMOKE_HOME/data" \
    XDG_CONFIG_HOME="$SMOKE_HOME/config" \
    XDG_CACHE_HOME="$SMOKE_HOME/cache" \
    XDG_RUNTIME_DIR="$SMOKE_HOME/run" \
    DBUS_SESSION_BUS_ADDRESS= \
    QT_QPA_PLATFORM=offscreen \
    timeout 5 "$OUTPUT" 2>&1)
smoke_rc=$?
set -e
rm -rf "$SMOKE_HOME"

if [[ $smoke_rc -ne 124 ]]; then
    echo "error: the AppImage did not stay up (exit $smoke_rc)" >&2
    echo "$smoke_out" >&2
    exit 1
fi
if grep -qiE "qrc:|\.qml:|is not installed|error" <<<"$smoke_out"; then
    echo "error: the AppImage booted but reported errors:" >&2
    echo "$smoke_out" >&2
    exit 1
fi
[[ -n "$smoke_out" ]] && { echo "  (startup output, not errors)"; echo "$smoke_out" | sed 's/^/    /'; }
echo "  watchboard booted from the AppImage and stayed up"
echo "AppImage created: $OUTPUT"
