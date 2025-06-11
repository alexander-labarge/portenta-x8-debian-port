#!/usr/bin/env bash
##############################################################################
# build_docker_arm64_static.sh
#   • Host  : Ubuntu 24.04 x86-64
#   • Output: docker-arm64-static/bin/{dockerd,docker} (static ARM64, v28.2.2)
##############################################################################
set -euo pipefail
say(){ printf '\033[1;36m[*] %s\033[0m\n' "$*"; }
ok(){  printf '\033[1;32m    → %s\033[0m\n' "$*"; }
die(){ printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# ── 1. Host sanity ──────────────────────────────────────────────────────────
source /etc/lsb-release
[[ $DISTRIB_ID == "Ubuntu" && $DISTRIB_RELEASE == "24.04" ]] \
  || die "Run on Ubuntu 24.04."

# ── 2. Build deps ───────────────────────────────────────────────────────────
say "Installing build deps"
sudo apt-get -qq update
sudo apt-get -qq install --yes --no-install-recommends \
  build-essential git wget ca-certificates xz-utils \
  crossbuild-essential-arm64 qemu-user-static

# ── 3. Exact Go tool-chain ──────────────────────────────────────────────────
GO_VER="1.24.4"
[[ -x /usr/local/go/bin/go ]] || sudo rm -rf /usr/local/go
if ! /usr/local/go/bin/go version 2>/dev/null | grep -q "go${GO_VER}" ; then
  say "Installing Go ${GO_VER}"
  wget -qO- "https://go.dev/dl/go${GO_VER}.linux-amd64.tar.gz" \
    | sudo tar -C /usr/local -xz
fi
export PATH=/usr/local/go/bin:$PATH
ok "Using $(go version)"

# ── 4. Globals ──────────────────────────────────────────────────────────────
DOCKER_VER="28.2.2"
PREFIX="$PWD/docker-arm64-static"
rm -rf "$PREFIX" && mkdir -p "$PREFIX/bin"
STRIP=aarch64-linux-gnu-strip
BUILDTAGS='osusergo netgo static_build no_devmapper no_btrfs \
           exclude_graphdriver_aufs exclude_graphdriver_zfs'
BUILD_TIME="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

ensure_go_mod() {      # promote vendor.mod → go.mod if go.mod is missing
  [[ -f go.mod ]] && return
  cp vendor.mod go.mod
  cp vendor.sum go.sum 2>/dev/null || :
  go mod tidy -e
}

# ── 5. Build dockerd ────────────────────────────────────────────────────────
say "Cloning moby/moby (v${DOCKER_VER})"
rm -rf moby && git clone --depth 1 -b "v${DOCKER_VER}" \
       https://github.com/moby/moby.git
pushd moby >/dev/null
ensure_go_mod
D_COMMIT=$(git rev-parse --short HEAD)

LDF_DOCKERD="-s -w \
-X github.com/docker/docker/dockerversion.Version=${DOCKER_VER} \
-X github.com/docker/docker/dockerversion.GitCommit=${D_COMMIT} \
-X github.com/docker/docker/dockerversion.BuildTime=${BUILD_TIME}"

say "Building dockerd (static, arm64, v${DOCKER_VER})"
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
go build -mod=vendor -tags "$BUILDTAGS" -trimpath -ldflags "${LDF_DOCKERD}" \
        -o dockerd ./cmd/dockerd
$STRIP --strip-all dockerd
cp dockerd "$PREFIX/bin/"
popd >/dev/null
ok "dockerd → $PREFIX/bin/dockerd"

# ── 6. Build docker CLI ─────────────────────────────────────────────────────
say "Cloning docker/cli (v${DOCKER_VER})"
rm -rf cli && git clone --depth 1 -b "v${DOCKER_VER}" \
       https://github.com/docker/cli.git
pushd cli >/dev/null
ensure_go_mod
C_COMMIT=$(git rev-parse --short HEAD)

LDF_CLI="-s -w \
-X github.com/docker/cli/cli/version.Version=${DOCKER_VER} \
-X github.com/docker/cli/cli/version.GitCommit=${C_COMMIT} \
-X github.com/docker/cli/cli/version.BuildTime=${BUILD_TIME}"

say "Building docker CLI (static, arm64, v${DOCKER_VER})"
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
go build -mod=vendor -tags 'osusergo netgo static_build' -trimpath \
        -ldflags "${LDF_CLI}" -o docker ./cmd/docker
$STRIP --strip-all docker
cp docker "$PREFIX/bin/"
popd >/dev/null
ok "docker  → $PREFIX/bin/docker"

# ── 7. Summary ──────────────────────────────────────────────────────────────
ok "Static Docker Engine v${DOCKER_VER} binaries:"
file "$PREFIX/bin/dockerd" "$PREFIX/bin/docker"
"$PREFIX/bin/docker" --version
"$PREFIX/bin/dockerd" --version || true
