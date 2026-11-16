#!/usr/bin/env bash
# Downloads the Linux .deb and .rpm packages of the latest release of every
# product listed in ./products (one GitHub repository per line) into a
# directory. Needs gh.
#
#   scripts/download.sh <dir>
set -euo pipefail

if [ $# -ne 1 ]; then
	echo "usage: $0 <dir>" >&2
	exit 2
fi
root=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$1"
while read -r repo; do
	case $repo in "" | "#"*) continue ;; esac
	gh release download --repo "$repo" --dir "$1" --clobber \
		--pattern '*_linux_*.deb' --pattern '*_linux_*.rpm'
done <"$root/products"
