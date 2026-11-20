#!/usr/bin/env bash
# package.sh — Bundle WatchBoard.app and create a DMG for macOS.
# Run from the project root with Qt's bin on PATH, after `cmake --build build`.
#
# Signing and notarization are opt-in through DEVELOPER_ID and the NOTARY_*
# variables; without them the app is signed ad hoc and the DMG is not notarized.
set -euo pipefail

# Portable on purpose: `grep -oP` is GNU-only and the BSD grep on macOS runners
# rejects it outright.
VERSION=$(sed -n 's/^project(.* VERSION \([0-9][0-9.]*\).*/\1/p' CMakeLists.txt | head -1)
APP="build/WatchBoard.app"
DIST="$(pwd)/dist"
DMG_NAME="WatchBoard-${VERSION}-macos.dmg"
STAGE_DIR="$(mktemp -d)/watchboard-dmg"

mkdir -p "$DIST" "$STAGE_DIR"

# ── macdeployqt ───────────────────────────────────────────────────────────────
# Mahina's QML is scanned along with the app's own: it imports modules
# (QtQuick.Effects, QtQml.Models, Dialogs) that nothing under src/qml does.
# Mahina itself is linked statically and served from qrc, so its build
# directory is only there to resolve `import Mahina`; the copy macdeployqt
# makes from it is removed before signing.
cache_dir() { sed -n "s/^$1:STATIC=//p" build/CMakeCache.txt | head -1; }
MAHINA_SRC="$(cache_dir Mahina_SOURCE_DIR)"
MAHINA_BIN="$(cache_dir Mahina_BINARY_DIR)"
if [ ! -d "$MAHINA_SRC/qml" ] || [ ! -f "$MAHINA_BIN/Mahina/qmldir" ]; then
    echo "error: Mahina's sources or build not found via build/CMakeCache.txt" >&2
    exit 1
fi

macdeployqt "$APP" \
    -qmldir=src/qml \
    -qmldir="$MAHINA_SRC/qml" \
    -qmlimportpath="$MAHINA_BIN" \
    -no-strip
rm -rf "$APP/Contents/Resources/qml/Mahina"

# QtSql arrives as a dependency of a QML module, and macdeployqt brings every
# SQL driver plugin with it. WatchBoard opens no database, and several of those
# plugins still name client libraries on Qt's build machine (Postgres.app,
# libiodbc, Mimer), which only produces otool errors here and dangling
# references in a signed bundle.
rm -rf "$APP/Contents/PlugIns/sqldrivers"

# ── Start what was just bundled ───────────────────────────────────────────────
# The bundled binary, not the build tree's, so a QML module macdeployqt missed
# shows up here ("module ... is not installed") and not on a user's Mac. It
# has to still be running after five seconds. macOS has no `timeout`.
echo "── smoke test ──"
SMOKE_LOG="$(mktemp)"
SMOKE_HOME="$(mktemp -d)"
HOME="$SMOKE_HOME" QT_QPA_PLATFORM=offscreen \
    "$APP/Contents/MacOS/WatchBoard" >"$SMOKE_LOG" 2>&1 &
smoke_pid=$!
sleep 5
if ! kill -0 "$smoke_pid" 2>/dev/null; then
    wait "$smoke_pid" || true
    echo "error: the bundled app did not stay up" >&2
    cat "$SMOKE_LOG" >&2
    exit 1
fi
kill "$smoke_pid"; wait "$smoke_pid" 2>/dev/null || true
if grep -qiE "qrc:|\.qml:|is not installed|error" "$SMOKE_LOG"; then
    echo "error: the bundled app booted but reported errors:" >&2
    cat "$SMOKE_LOG" >&2
    exit 1
fi
rm -rf "$SMOKE_LOG" "$SMOKE_HOME"
echo "  WatchBoard booted from the bundle and stayed up"

# ── Code-sign ─────────────────────────────────────────────────────────────────
# With DEVELOPER_ID set this is a real Developer ID signature: hardened runtime,
# which notarization refuses to proceed without, and a secure timestamp, which
# is what keeps builds already in people's hands valid after the certificate
# behind them expires. Without it, an ad-hoc signature — enough for macOS to run
# the app on the machine that built it, not enough for anyone else's.
#
# Signed inside out rather than with --deep. Apple has discouraged --deep for
# years: it hands the same options to everything it finds and is documented as a
# way to repair a bundle rather than to sign one. macdeployqt leaves dozens of
# dylibs and a stack of Qt frameworks in here, and each has to be signed before
# whatever contains it — a bundle's signature seals what is inside it, so
# signing the outside first only invalidates it on the next inner change.
if [ -n "${DEVELOPER_ID:-}" ]; then
    sign() { codesign --force --timestamp --options runtime --sign "$DEVELOPER_ID" "$@"; }

    echo "Signing with: $DEVELOPER_ID"

    # Loose libraries and plugins first. Qt's own framework binaries carry no
    # extension, so this matches the deployed dylibs without reaching into them.
    while IFS= read -r -d '' f; do sign "$f"; done < <(
        find "$APP/Contents" -type f \( -name '*.dylib' -o -name '*.so' \) -print0)

    # Then each framework bundle as a whole.
    while IFS= read -r -d '' f; do sign "$f"; done < <(
        find "$APP/Contents/Frameworks" -maxdepth 1 -name '*.framework' -print0)

    # Then the app, which is the only part that carries entitlements.
    sign --entitlements packaging/macos/entitlements.plist "$APP"

    codesign --verify --deep --strict --verbose=2 "$APP"
else
    codesign --deep --force --sign - "$APP"
fi

# ── Create DMG ────────────────────────────────────────────────────────────────
cp -R "$APP" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

hdiutil create \
    -volname "WatchBoard $VERSION" \
    -srcfolder "$STAGE_DIR" \
    -ov -format UDZO \
    "$DIST/$DMG_NAME"

rm -rf "$STAGE_DIR"
echo "DMG created: $DIST/$DMG_NAME"

# ── Sign, notarize and staple the DMG ─────────────────────────────────────────
# The app inside is signed already; the disk image around it is a separate file
# and needs its own signature. Notarization then sends the whole thing to Apple,
# which scans it and issues a ticket, and stapling writes that ticket into the
# DMG so a Mac that has never been online can still verify it. Skipping any of
# the three leaves the download exactly as blocked as an unsigned one.
if [ -n "${DEVELOPER_ID:-}" ]; then
    codesign --force --timestamp --sign "$DEVELOPER_ID" "$DIST/$DMG_NAME"

    # Two doors, because two things run this script. A developer on their own
    # Mac stores credentials once with `xcrun notarytool store-credentials` and
    # names the profile here; CI has no keychain to keep a profile in and passes
    # an App Store Connect API key instead, which can be revoked on its own and
    # is not tied to anybody's Apple ID password.
    NOTARY_ARGS=()
    if [ -n "${NOTARY_PROFILE:-}" ]; then
        NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
    elif [ -n "${NOTARY_KEY:-}" ]; then
        NOTARY_ARGS=(--key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
    fi

    if [ ${#NOTARY_ARGS[@]} -gt 0 ]; then
        # `notarytool submit --wait` does two very different jobs in one command:
        # it uploads the DMG, and then it holds a single long connection open
        # while Apple's queue works through it. The queue can take the better
        # part of an hour, and any network hiccup in that hour kills the command
        # — with a non-zero exit, as if the submission had been rejected, when in
        # fact it is alive on Apple's side and about to be accepted. That is a
        # release build thrown away over a dropped packet.
        #
        # So the two jobs are separated. The upload happens once, and the waiting
        # is a poll that can fail and be tried again: an unreadable status is
        # treated as "ask again in thirty seconds", and only a verdict from Apple
        # ends the loop either way.
        SUBMISSION_ID="$(xcrun notarytool submit "$DIST/$DMG_NAME" \
                             "${NOTARY_ARGS[@]}" --no-wait \
                         | sed -n 's/^ *id: *//p' | head -1)"
        if [ -z "$SUBMISSION_ID" ]; then
            echo "error: notarytool accepted no submission — nothing to wait for." >&2
            exit 1
        fi
        echo "Notarization submission: $SUBMISSION_ID"

        # 120 × 30s = one hour, which is past anything Apple's queue has taken
        # here and still short enough to fit inside the job's own timeout.
        NOTARY_STATUS=""
        for _ in $(seq 1 120); do
            sleep 30
            NOTARY_STATUS="$(xcrun notarytool info "$SUBMISSION_ID" \
                                 "${NOTARY_ARGS[@]}" 2>/dev/null \
                             | sed -n 's/^ *status: *//p' | head -1)"
            case "$NOTARY_STATUS" in
                Accepted)          echo "Notarization accepted."; break ;;
                Invalid|Rejected)  break ;;
                "")                echo "  (status unreadable — retrying)" ;;
                *)                 echo "  status: $NOTARY_STATUS" ;;
            esac
        done

        # The log is worth printing either way: on a rejection it is the only
        # place that says which binary Apple objected to, and on an acceptance it
        # still lists the warnings that will become rejections later.
        xcrun notarytool log "$SUBMISSION_ID" "${NOTARY_ARGS[@]}" || true

        if [ "$NOTARY_STATUS" != "Accepted" ]; then
            echo "error: notarization ended as '${NOTARY_STATUS:-unknown}'." >&2
            echo "       Resume with: xcrun notarytool info $SUBMISSION_ID …" >&2
            exit 1
        fi

        # Stapling reaches out to Apple too, and fails the same transient way.
        for attempt in 1 2 3; do
            if xcrun stapler staple "$DIST/$DMG_NAME"; then
                break
            fi
            if [ "$attempt" = 3 ]; then
                echo "error: could not staple the ticket after three tries." >&2
                exit 1
            fi
            echo "stapler failed (attempt $attempt) — retrying in 30s" >&2
            sleep 30
        done
        xcrun stapler validate "$DIST/$DMG_NAME"
        echo "DMG signed, notarized and stapled."
    else
        echo "warning: signed but NOT notarized — no NOTARY_PROFILE or NOTARY_KEY" >&2
        echo "         set. Gatekeeper blocks this DMG on any other Mac." >&2
    fi
fi
