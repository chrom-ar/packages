#!/bin/sh
# Installs the Collector CLI (collector) on macOS or Linux, amd64 or arm64:
#
#   curl -fsSL https://packages.chrom.ar/collector/install.sh | sh
#
# It downloads the latest release from GitHub, checks it against the
# release's checksums.txt, and puts collector in $COLLECTOR_INSTALL_DIR,
# else /usr/local/bin when writable, else ~/.local/bin. Run it again to
# upgrade. COLLECTOR_VERSION=1.2.3 picks a release.
set -eu

repo=chrom-ar/collector-cli
base=${COLLECTOR_DOWNLOAD_URL:-https://github.com/$repo/releases}

fail() {
	echo "collector install: $*" >&2
	exit 1
}

case $(uname -s) in
Darwin) os=darwin ;;
Linux) os=linux ;;
*) fail "unsupported system $(uname -s); see https://github.com/$repo#install" ;;
esac
case $(uname -m) in
x86_64 | amd64) arch=amd64 ;;
arm64 | aarch64) arch=arm64 ;;
*) fail "unsupported processor $(uname -m); see https://github.com/$repo#install" ;;
esac

if [ -n "${COLLECTOR_VERSION:-}" ]; then
	url=$base/download/v${COLLECTOR_VERSION#v}
else
	url=$base/latest/download
fi
archive=collector_${os}_${arch}.tar.gz

if command -v curl >/dev/null 2>&1; then
	get() { curl -fsSL -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
	get() { wget -q -O "$2" "$1"; }
else
	fail "needs curl or wget"
fi
if command -v sha256sum >/dev/null 2>&1; then
	sum() { sha256sum "$1" | cut -d' ' -f1; }
elif command -v shasum >/dev/null 2>&1; then
	sum() { shasum -a 256 "$1" | cut -d' ' -f1; }
else
	fail "needs sha256sum or shasum to check the download"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

get "$url/$archive" "$tmp/$archive" || fail "couldn't download $url/$archive"
get "$url/checksums.txt" "$tmp/checksums.txt" || fail "couldn't download $url/checksums.txt"
want=$(awk -v f="$archive" '$2 == f { print $1 }' "$tmp/checksums.txt")
[ -n "$want" ] || fail "checksums.txt doesn't list $archive"
[ "$(sum "$tmp/$archive")" = "$want" ] || fail "$archive doesn't match its checksum; not installing it"
tar -xzf "$tmp/$archive" -C "$tmp" collector

dir=${COLLECTOR_INSTALL_DIR:-}
if [ -z "$dir" ]; then
	if [ -w /usr/local/bin ]; then
		dir=/usr/local/bin
	else
		dir=$HOME/.local/bin
	fi
fi
mkdir -p "$dir"
mv "$tmp/collector" "$dir/collector"
chmod 0755 "$dir/collector"

echo "Installed $("$dir/collector" --version) in $dir."
case ":$PATH:" in
*":$dir:"*) ;;
*) echo "Add $dir to your PATH, e.g.: echo 'export PATH=\"$dir:\$PATH\"' >> ~/.profile" ;;
esac
echo "Next: collector login"
