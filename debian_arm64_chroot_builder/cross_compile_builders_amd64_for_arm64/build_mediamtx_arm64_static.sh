#!/usr/bin/env bash
##############################################################################
# build_mediamtx_arm64_static.sh
#   • Host  : Ubuntu 24.04 x86-64
#   • Output: mediamtx-arm64-static/bin/mediamtx (fully static, AArch64)
##############################################################################
set -euo pipefail

say(){ printf '\033[1;36m[*] %s\033[0m\n' "$*"; }
ok(){  printf '\033[1;32m    → %s\033[0m\n' "$*"; }
die(){ printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }

# ── 1. Host sanity ──────────────────────────────────────────────────────────
source /etc/lsb-release
[[ $DISTRIB_ID == Ubuntu && $DISTRIB_RELEASE == 24.04 ]] || \
  die "Run this script on Ubuntu 24.04."

# ── 2. Packages ─────────────────────────────────────────────────────────────
say "Installing build dependencies"
sudo apt-get -qq update
sudo apt-get -qq install --yes --no-install-recommends \
  build-essential git wget curl ca-certificates xz-utils \
  crossbuild-essential-arm64 qemu-user-static

# ── 3. Go tool-chain (exact version) ────────────────────────────────────────
GO_VER="1.24.4"
GO_URL="https://go.dev/dl/go${GO_VER}.linux-amd64.tar.gz"

if [[ ! -x /usr/local/go/bin/go || "$(/usr/local/go/bin/go version | awk '{print $3}')" != "go${GO_VER}" ]]; then
  say "Installing Go ${GO_VER}"
  sudo rm -rf /usr/local/go
  sudo mkdir -p /usr/local
  wget -qO- "$GO_URL" | sudo tar -C /usr/local -xz
fi
export PATH=/usr/local/go/bin:$PATH
ok "$(/usr/local/go/bin/go version)"

# ── 4. Install prefix ───────────────────────────────────────────────────────
PREFIX="$PWD/mediamtx-arm64-static"
rm -rf "$PREFIX"; mkdir -p "$PREFIX/bin"

# ── 5. Clone and generate assets ────────────────────────────────────────────
say "Cloning mediamtx"
git clone --quiet --depth 1 https://github.com/bluenviron/mediamtx.git
pushd mediamtx > /dev/null

git describe --tags --always > VERSION   # embed version string
go generate ./...                       # fetch hls.js & rpicamera assets

# ── 6. Build fully-static arm64 binary ──────────────────────────────────────
say "Building static mediamtx (arm64)"
CGO_ENABLED=0 \
GOOS=linux GOARCH=arm64 \
go build -trimpath -ldflags '-s -w' -o mediamtx .

CROSS=aarch64-linux-gnu      # binutils triplet from crossbuild-essential-arm64
$CROSS-strip --strip-all mediamtx

cp mediamtx "$PREFIX/bin/"
popd > /dev/null
ok "mediamtx installed to $PREFIX/bin/"

# ── 7. Result summary ───────────────────────────────────────────────────────
ok "Finished:"
file "$PREFIX/bin/mediamtx"
"$PREFIX/bin/mediamtx" --version || true
