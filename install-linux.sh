#!/bin/bash

CUR_VERSION=""
NEW_VERSION="$(curl -s https://api.github.com/repos/Tenderly/tenderly-cli/releases/latest | jq -r '.tag_name' | sed 's/^v//')"
EXISTS="$(command -v tenderly)"

printf "Installing version %s\n" $NEW_VERSION

cd /tmp/ > /dev/null

tarball="tenderly-binary.tar.gz"

curl -s https://api.github.com/repos/Tenderly/tenderly-cli/releases/latest \
| grep "browser_download_url.*Linux_amd64\.tar\.gz" \
| cut -d ":" -f 2,3 \
| tr -d \" \
| xargs curl -sLo $tarball

tar -xzf $tarball

chmod +x tenderly

unlink $tarball

printf "Moving CLI to /usr/local/bin/\n"

mv tenderly /usr/local/bin/

cd - > /dev/null

location="$(which tenderly)"
printf "Tenderly CLI installed to: %s\n" $location

version="$(tenderly version | sed -n 1p | cut -d'v' -f3)"
printf "New Tenderly version installed: %s\n" $version
