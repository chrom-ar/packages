#!/usr/bin/env bash
# Runs collector/install.sh against a folder of release archives (collector-cli's
# dist/ after make release-snapshot), served locally, on Debian and Alpine:
# it installs, the binary runs, and a tampered archive is refused. Needs
# Docker.
#
#   scripts/test-install.sh <dist dir>
set -euo pipefail

if [ $# -ne 1 ]; then
	echo "usage: $0 <dist dir>" >&2
	exit 2
fi
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
net=chroma-install-test-$$
cleanup() {
	docker rm -f "$net-site" >/dev/null 2>&1 || true
	docker network rm "$net" >/dev/null 2>&1 || true
	rm -rf "$work"
}
trap cleanup EXIT

mkdir -p "$work/site/latest/download" "$work/bad/latest/download"
cp "$1"/collector_linux_*.tar.gz "$1"/checksums.txt "$work/site/latest/download/"
cp "$work/site/latest/download/"* "$work/bad/latest/download/"
for f in "$work/bad/latest/download/"*.tar.gz; do echo tampered >>"$f"; done
chmod -R a+rX "$work"

docker network create "$net" >/dev/null
docker run -d --name "$net-site" --network "$net" -v "$work:/srv:ro" \
	python:3-alpine python -m http.server 8000 --directory /srv >/dev/null
url=http://$net-site:8000

for image in debian:stable-slim alpine:latest; do
	echo "== $image"
	docker run --rm --network "$net" -v "$root/collector/install.sh:/install.sh:ro" "$image" sh -euc '
		command -v curl >/dev/null || { apt-get update -qq >/dev/null 2>&1 && apt-get install -qq -y curl >/dev/null 2>&1; } || apk add -q curl
		until curl -fsS '"$url"'/site/latest/download/checksums.txt >/dev/null; do sleep 1; done
		COLLECTOR_DOWNLOAD_URL='"$url"'/site sh /install.sh
		collector --version
		if COLLECTOR_DOWNLOAD_URL='"$url"'/bad COLLECTOR_INSTALL_DIR=/tmp/bad sh /install.sh; then
			echo "a tampered archive was installed" >&2; exit 1
		fi
		test ! -e /tmp/bad/collector
	'
done
echo "== ok"
