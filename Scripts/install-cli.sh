#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME="HiMilo"
APP_BUNDLE="$ROOT/${APP_NAME}.app"
INSTALL_DIR="/usr/local/bin"
CLI_NAME="milo"

# Build the app bundle if it doesn't exist.
if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "App bundle not found. Packaging first..."
    SIGNING_MODE=adhoc "$ROOT/Scripts/package_app.sh" release
fi

BINARY_PATH="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

if [[ ! -f "$BINARY_PATH" ]]; then
    echo "ERROR: Binary not found at $BINARY_PATH" >&2
    exit 1
fi

echo "Installing ${CLI_NAME} to ${INSTALL_DIR}..."

if [[ -L "${INSTALL_DIR}/${CLI_NAME}" || -f "${INSTALL_DIR}/${CLI_NAME}" ]]; then
    echo "Removing existing ${INSTALL_DIR}/${CLI_NAME}..."
    rm -f "${INSTALL_DIR}/${CLI_NAME}"
fi

ln -s "$BINARY_PATH" "${INSTALL_DIR}/${CLI_NAME}"
echo "Installed: ${INSTALL_DIR}/${CLI_NAME} -> ${BINARY_PATH}"
echo ""
echo "Usage:"
echo "  milo \"Hello, world!\""
echo "  echo \"Read this\" | milo"
echo "  milo --clipboard"
echo "  milo --listen"
echo "  milo  # (menu bar mode)"
