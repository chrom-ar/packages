# Chroma packages

Install [`collector`](https://github.com/chrom-ar/collector-cli), the
command-line client for Collector.

## macOS and Linux

```sh
curl -fsSL https://packages.chrom.ar/collector/install.sh | sh
```

Run it again to upgrade.

## Debian, Ubuntu

```sh
curl -fsSL https://packages.chrom.ar/chroma.gpg | sudo tee /usr/share/keyrings/chroma.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/chroma.gpg] https://packages.chrom.ar/apt stable main" | sudo tee /etc/apt/sources.list.d/chroma.list
sudo apt update && sudo apt install collector
```

Upgrade with `sudo apt update && sudo apt upgrade`.

## Fedora, RHEL

```sh
sudo curl -fsSLo /etc/yum.repos.d/chroma.repo https://packages.chrom.ar/rpm/chroma.repo
sudo dnf install collector
```

Upgrade with `sudo dnf upgrade`.

## openSUSE

```sh
sudo zypper addrepo https://packages.chrom.ar/rpm/chroma.repo
sudo zypper install collector
```

Upgrade with `sudo zypper update`.

## Uninstall

```sh
# Debian, Ubuntu
sudo apt remove collector
sudo rm /etc/apt/sources.list.d/chroma.list /usr/share/keyrings/chroma.gpg

# Fedora, RHEL
sudo dnf remove collector
sudo rm /etc/yum.repos.d/chroma.repo

# openSUSE
sudo zypper remove collector
sudo zypper removerepo chroma
```

Packages are signed with `Chroma <admin@chrom.ar>`, fingerprint
`TO BE FILLED IN ONCE THE KEY EXISTS`.
