#!/usr/bin/env sh
set -e

APP_NAME="carbonara"
REPO="atasoya/carbonara"

echo "Installing $APP_NAME..."

OS="$(uname -s)"
ARCH="$(uname -m)"

if [ "$OS" != "Linux" ]; then
  echo "Error: this installer only supports Linux."
  exit 1
fi

case "$ARCH" in
  x86_64)
    DEB_ARCH="amd64"
    ;;
  *)
    echo "Error: unsupported architecture: $ARCH"
    echo "Currently only x86_64 / amd64 Linux is supported."
    exit 1
    ;;
esac

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required."
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "Error: sudo is required."
  exit 1
fi

if ! command -v apt >/dev/null 2>&1; then
  echo "Error: apt is required. This installer supports Debian/Ubuntu-based systems."
  exit 1
fi

LATEST_URL="https://github.com/$REPO/releases/latest/download/${APP_NAME}_${DEB_ARCH}.deb"

TMP_FILE="$(mktemp "/tmp/${APP_NAME}.XXXXXX.deb")"
trap 'rm -f "$TMP_FILE"' EXIT

echo "Downloading: $LATEST_URL"
curl -fL "$LATEST_URL" -o "$TMP_FILE"

echo "Installing package..."
sudo apt install -y "$TMP_FILE"

echo "$APP_NAME installed successfully!"
echo "Run it with:"
echo "  $APP_NAME"
