#!/usr/bin/env bash
# Builds the repositories with a throwaway key, serves them, and installs
# collector from them with apt (Debian) and dnf (Fedora), each verifying
# the signatures. Needs Docker; and gh, unless given a directory of
# packages (e.g. collector-cli's dist/ after make release-snapshot).
#
#   scripts/test.sh [<packages dir>]
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
net=chroma-packages-test-$$
cleanup() {
	docker rm -f "$net-site" >/dev/null 2>&1 || true
	docker network rm "$net" >/dev/null 2>&1 || true
	rm -rf "$work"
}
trap cleanup EXIT

mkdir "$work/pkgs"
if [ $# -ge 1 ]; then
	cp "$1"/*_linux_*.deb "$1"/*_linux_*.rpm "$work/pkgs/"
else
	"$root/scripts/download.sh" "$work/pkgs"
fi

docker network create "$net" >/dev/null
url=http://$net-site:8000

echo "== build"
docker run --rm -e DEBIAN_FRONTEND=noninteractive -e OWNER="$(id -u):$(id -g)" -v "$root/scripts:/scripts:ro" -v "$work:/work" ubuntu:24.04 bash -euc '
	apt-get update -qq >/dev/null
	apt-get install -qq -y apt-utils createrepo-c rpm gpg >/dev/null
	# A short path: gpg-agent fails on long socket paths.
	export GNUPGHOME=$(mktemp -d /tmp/g.XXXX)
	gpg --batch --quiet --passphrase "" --quick-gen-key "Chroma test <test@example.com>" rsa4096 sign never
	KEY=test@example.com /scripts/build.sh /work/pkgs /work/site '"$url"'
	# Root in here; hand the site back so the cleanup can remove it.
	chown -R "$OWNER" /work/site
	chmod -R a+rX /work/site
'

docker run -d --name "$net-site" --network "$net" -v "$work/site:/site:ro" \
	python:3-alpine python -m http.server 8000 --directory /site >/dev/null

echo "== apt (Debian)"
docker run --rm --network "$net" -e DEBIAN_FRONTEND=noninteractive debian:stable-slim bash -euc '
	apt-get update -qq >/dev/null && apt-get install -qq -y curl >/dev/null
	until curl -fsS '"$url"'/chroma.gpg -o /usr/share/keyrings/chroma.gpg; do sleep 1; done
	echo "deb [signed-by=/usr/share/keyrings/chroma.gpg] '"$url"'/apt stable main" >/etc/apt/sources.list.d/chroma.list
	apt-get update -qq >/dev/null
	apt-get install -qq -y collector >/dev/null
	collector --version
'

echo "== dnf (Fedora)"
docker run --rm --network "$net" fedora:latest bash -euc '
	curl -fsS '"$url"'/rpm/chroma.repo -o /etc/yum.repos.d/chroma.repo
	dnf install -q -y collector
	rpm -q --qf "%{NAME} %{VERSION} signed: %{RSAHEADER:pgpsig}\n" collector
	collector --version
'
echo "== ok"
