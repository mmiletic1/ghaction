#!/bin/bash

# Define retry parameters
MAX_RETRIES=5
RETRY_DELAY_SECONDS=5 # Initial delay, can be increased with backoff if desired

CUR_VERSION=""

# Function to fetch GitHub API data with retries
fetch_github_api_with_retries() {
  url="$1" # Uklonjeno 'local'
  attempts=0
  response=""

  while [ $attempts -lt $MAX_RETRIES ]; do
    response=$(curl -s "$url")
    if [ -n "$response" ] && ! echo "$response" | grep -q "rate limit exceeded"; then
      # Success: response received and no rate limit message
      echo "$response"
      return 0
    fi

    attempts=$((attempts + 1))
    echo "Warning: Attempt $attempts failed to fetch API ($url). Retrying in ${RETRY_DELAY_SECONDS}s..." >&2
    sleep "$RETRY_DELAY_SECONDS"
    # Optional: increase RETRY_DELAY_SECONDS for exponential backoff: RETRY_DELAY_SECONDS=$((RETRY_DELAY_SECONDS * 2))
  done

  echo "Error: Failed to fetch GitHub API data from $url after $MAX_RETRIES attempts." >&2
  return 1 # Failed after retries
}

# Fetch latest version using the retry function
API_RESPONSE=$(fetch_github_api_with_retries "https://api.github.com/repos/Tenderly/tenderly-cli/releases/latest")

if [ $? -ne 0 ]; then
  echo "Exiting due to failure fetching Tenderly CLI release information."
  exit 1
fi

NEW_VERSION=$(echo "$API_RESPONSE" | grep tag_name | cut -d'v' -f2 | cut -d'"' -f1)

EXISTS="$(command -v tenderly)"

if [ "$EXISTS" != "" ]; then
  CUR_VERSION="$(tenderly version | sed -n 1p | cut -d'v' -f3)"
  printf "\nCurrent Version: %s => New Version: %s\n" "$CUR_VERSION" "$NEW_VERSION"
fi

# Basic check if NEW_VERSION was successfully retrieved
if [ -z "$NEW_VERSION" ]; then
  echo "Error: Could not determine the latest Tenderly CLI version from API response. Exiting."
  exit 1
fi

if [ "$NEW_VERSION" != "$CUR_VERSION" ]; then

  printf "Installing version %s\n" "$NEW_VERSION"

  # Change to /tmp/ for temporary downloads
  if ! cd /tmp/; then
    echo "Error: Could not change directory to /tmp/. Exiting."
    exit 1
  fi

  tarball="tenderly-binary.tar.gz"

  # Robust download URL extraction from the already fetched API_RESPONSE
  DOWNLOAD_URL=$(echo "$API_RESPONSE" \
  | grep "browser_download_url.*Linux_amd64\.tar\.gz" \
  | awk -F '"' '{print $4}') # Robustly extracts the URL directly from the JSON field

  if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Could not determine download URL for Tenderly CLI from API response. Exiting."
    exit 1
  fi

  printf "Downloading from: %s\n" "$DOWNLOAD_URL"
  # Download the tarball with retries
  attempts=0
  while [ $attempts -lt $MAX_RETRIES ]; do
    if curl -sLo "$tarball" "$DOWNLOAD_URL"; then
      break # Success, exit retry loop
    fi
    attempts=$((attempts + 1))
    echo "Warning: Attempt $attempts failed to download binary. Retrying in ${RETRY_DELAY_SECONDS}s..." >&2
    sleep "$RETRY_DELAY_SECONDS"
  done

  if [ ! -f "$tarball" ]; then
    echo "Error: Downloaded file '$tarball' not found or download failed after $MAX_RETRIES attempts. Exiting."
    exit 1
  fi

  # Extract the tarball
  if ! tar -xzf "$tarball"; then
    echo "Error: Failed to extract '$tarball'. Corrupted download or tar issue. Exiting."
    exit 1
  fi

  if [ ! -f "tenderly" ]; then
    echo "Error: 'tenderly' executable not found after extraction from '$tarball'. Exiting."
    exit 1
  fi

  # Make executable
  if ! chmod +x tenderly; then
    echo "Error: Failed to make 'tenderly' executable. Exiting."
    exit 1
  fi

  # Remove tarball
  if ! unlink "$tarball"; then
    echo "Warning: Could not unlink '$tarball'."
  fi

  printf "Moving CLI to /usr/local/bin/\n"

  # Move to /usr/local/bin/
  if ! mv tenderly /usr/local/bin/; then
    echo "Error: Failed to move 'tenderly' to /usr/local/bin/. Do you have sufficient permissions? Exiting."
    exit 1
  fi

  # Return to original directory
  cd - > /dev/null

  location="$(which tenderly)"
  printf "Tenderly CLI installed to: %s\n" "$location"

  # Verify new version
  if command -v tenderly &> /dev/null; then
    version="$(tenderly version | sed -n 1p | cut -d'v' -f3)"
    printf "New Tenderly version installed: %s\n" "$version"
  else
    echo "Warning: Tenderly CLI does not appear to be in your PATH after installation. You may need to refresh your shell."
  fi

else
  printf "Latest version already installed\n"
fi
