#!/bin/bash
set -euo pipefail

echo "📦 Checking Tenderly CLI latest version..."

TENDERLY_API="https://api.github.com/repos/Tenderly/tenderly-cli/releases/latest"
TARBALL="tenderly-binary.tar.gz"
TMP_DIR="/tmp/tenderly-cli"
INSTALL_PATH="/usr/local/bin/tenderly"

# Get latest version (strip "v" prefix if needed)
NEW_VERSION=$(curl -s $TENDERLY_API | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')

if [[ -z "$NEW_VERSION" ]]; then
  echo "❌ Failed to fetch latest version from GitHub API."
  exit 1
fi

echo "🔍 Latest version: $NEW_VERSION"

# Check current version if already installed
if command -v tenderly &>/dev/null; then
  CUR_VERSION=$(tenderly version | head -n1 | sed -E 's/.*v([0-9.]+).*/\1/')
  echo "📍 Current version: $CUR_VERSION"

  if [[ "$CUR_VERSION" == "$NEW_VERSION" ]]; then
    echo "✅ Latest version already installed."
    exit 0
  fi
else
  echo "ℹ️ Tenderly CLI not currently installed."
fi

echo "⬇️ Downloading Tenderly CLI v$NEW_VERSION..."

# Extract download URL
DOWNLOAD_URL=$(curl -s $TENDERLY_API \
  | grep "browser_download_url.*Linux_amd64.*\.tar\.gz" \
  | cut -d '"' -f 4)

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "❌ Failed to extract download URL for Linux_amd64 tar.gz"
  exit 1
fi

mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

curl -sL "$DOWNLOAD_URL" -o "$TARBALL"
tar -xzf "$TARBALL"
chmod +x tenderly
sudo mv tenderly "$INSTALL_PATH"

cd - > /dev/null
rm -rf "$TMP_DIR"

echo "✅ Tenderly CLI installed to: $INSTALL_PATH"
echo "🚀 Installed version: $(tenderly version | head -n1)"
