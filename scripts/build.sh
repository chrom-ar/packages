#!/usr/bin/env bash
# Builds Chroma's signed apt and dnf repositories from a directory of
# .deb and .rpm packages. The publish workflow runs it and serves the result
# on GitHub Pages; scripts/test.sh runs it against real package managers.
#
#   KEY=<signing key> scripts/build.sh <packages dir> <site dir> <site url>
#
# KEY names the signing key in gpg's keyring. Needs apt-ftparchive
# (apt-utils), createrepo_c, rpmsign (rpm) and gpg. Only the packages given
# are served: a package manager installs and upgrades to the newest anyway.
set -euo pipefail

if [ $# -ne 3 ] || [ -z "${KEY:-}" ]; then
	echo "usage: KEY=<signing key> $0 <packages dir> <site dir> <site url>" >&2
	exit 2
fi
pkgs=$(cd "$1" && pwd)
site=$2
url=${3%/}

shopt -s nullglob
debs=("$pkgs"/*.deb)
rpms=("$pkgs"/*.rpm)
if [ ${#debs[@]} -eq 0 ] || [ ${#rpms[@]} -eq 0 ]; then
	echo "$0: no .deb or no .rpm in $pkgs" >&2
	exit 1
fi

sign() { gpg --batch --yes --local-user "$KEY" "$@"; }

rm -rf "$site"
mkdir -p "$site/apt/pool" "$site/rpm"
site=$(cd "$site" && pwd)

# The public key, armored (dnf, zypper) and binary (apt's signed-by).
gpg --batch --export --armor "$KEY" >"$site/chroma.asc"
gpg --batch --export "$KEY" >"$site/chroma.gpg"

# apt: one suite, "stable", one component, "main".
cp "${debs[@]}" "$site/apt/pool/"
(
	cd "$site/apt"
	for arch in amd64 arm64; do
		dir=dists/stable/main/binary-$arch
		mkdir -p "$dir"
		apt-ftparchive --arch "$arch" packages pool >"$dir/Packages"
		gzip -9kn "$dir/Packages"
	done
	apt-ftparchive \
		-o APT::FTPArchive::Release::Origin=Chroma \
		-o APT::FTPArchive::Release::Label=Chroma \
		-o APT::FTPArchive::Release::Suite=stable \
		-o APT::FTPArchive::Release::Codename=stable \
		-o APT::FTPArchive::Release::Architectures="amd64 arm64" \
		-o APT::FTPArchive::Release::Components=main \
		release dists/stable >Release.tmp
	mv Release.tmp dists/stable/Release
	sign --clearsign --output dists/stable/InRelease dists/stable/Release
	sign --armor --detach-sign --output dists/stable/Release.gpg dists/stable/Release
)

# dnf and zypper: each package signed, and the metadata.
cp "${rpms[@]}" "$site/rpm/"
rpmsign --define "_gpg_name $KEY" --define "__gpg $(command -v gpg)" --addsign "$site"/rpm/*.rpm >/dev/null
createrepo_c --quiet "$site/rpm"
sign --armor --detach-sign --output "$site/rpm/repodata/repomd.xml.asc" "$site/rpm/repodata/repomd.xml"
cat >"$site/rpm/chroma.repo" <<EOF
[chroma]
name=Chroma
baseurl=$url/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$url/chroma.asc
EOF

# Each tool's one-line installer for macOS and Linux, at /<tool>/install.sh.
for installer in "$(dirname "$0")"/../*/install.sh; do
	tool=$(basename "$(dirname "$installer")")
	mkdir -p "$site/$tool"
	cp "$installer" "$site/$tool/install.sh"
done

# People who open the site, or a repository's folder, in a browser get the
# install instructions.
for dir in "$site" "$site/apt" "$site/rpm"; do
	cat >"$dir/index.html" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Chroma packages</title>
<meta http-equiv="refresh" content="0; url=https://github.com/chrom-ar/packages#readme">
<p>Install instructions: <a href="https://github.com/chrom-ar/packages#readme">github.com/chrom-ar/packages</a>.</p>
HTML
done
