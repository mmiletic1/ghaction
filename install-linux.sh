#!/bin/bash

set -euo pipefail

CUR_VERSION=""
TENDERLY_BIN="tenderly"
TARBALL="tenderly-binary.tar.gz"
TMP_DIR="/tmp/tenderly-cli-update"
LATEST_API="https://api.github.com/repos/Tenderly/tenderly-cli/releases/latest"

# Get latest version
NEW_VERSION=$(curl -s $LATEST_API | grep '"tag_name":' | cut -d'v' -f2 | cut -d'"' -f1)

# Check if Tenderly is installed
if command -v $TENDERLY_BIN &> /dev/null; then
  CUR_VERSION=$($TENDERLY_BIN version | sed -n 1p | cut -d'v' -f3)
  echo -e "\nCurrent Version: $CUR_VERSION => New Version: $NEW_VERSION"
else
  echo -e "\nTenderly CLI not found. Will install fresh version $NEW_VERSION."
fi

# Compare and install if needed
if [ "$NEW_VERSION" != "$CUR_VERSION" ]; then
  echo "Installing version $NEW_VERSION..."

  mkdir -p $TMP_DIR
  cd $TMP_DIR > /dev/null

  # Download tarball
  curl -s $LATEST_API \
    | grep "browser_download_url.*Linux_amd64\.tar\.gz" \
    | cut -d ":" -f2,3 \
    | tr -d \" \
    | xargs curl -sLo $TARBALL

  # Extract and move binary
  tar -xzf $TARBALL
  chmod +x $TENDERLY_BIN
  sudo mv $TENDERLY_BIN /usr/local/bin/

  echo "Tenderly CLI installed to: $(which $TENDERLY_BIN)"
  echo "New Tenderly version installed: $($TENDERLY_BIN version | sed -n 1p | cut -d'v' -f3)"

  cd - > /dev/null
  rm -rf $TMP_DIR
else
  echo "Latest version already installed."
fi
