#!/bin/sh
##############################################################################
# build_mediamtx_static.sh · Portenta-X8 (Yocto) all-in-one builder
#
# • Calls get_debian_rootfs.sh if /opt/bookworm-rootfs is missing
# • Uses chroot_debian_rootfs.sh for every chrooted command
# • Installs Go (if missing) inside the chroot (BusyBox tar + xzcat only)
# • Clones mediamtx, embeds static assets, builds CGO-free binary
# • Copies single binary to /usr/local/bin/mediamtx on Yocto
##############################################################################
set -eu

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
GET_ROOTFS="$SELF_DIR/get_debian_rootfs.sh"
CHROOT_SH="$SELF_DIR/chroot_debian_rootfs.sh"

ROOTFS="/opt/bookworm-rootfs"
MEDI_BIN_OUT="/usr/local/bin/mediamtx"
GO_VER="1.22.3"
GO_URL="https://go.dev/dl/go${GO_VER}.linux-arm64.tar.gz"

[ -x "$CHROOT_SH" ] || { echo "ERROR: $CHROOT_SH not found"; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }

##############################################################################
# helper: run command(s) inside chroot via wrapper (stdin → /bin/sh -c)
##############################################################################
in_chroot() {
    printf '%s\nexit\n' "$1" | ROOTFS_DIR="$ROOTFS" "$CHROOT_SH" >/dev/null
}

##############################################################################
# 1. Ensure Debian rootfs exists
##############################################################################
if [ ! -d "$ROOTFS" ]; then
    echo "[*] Rootfs not found – invoking get_debian_rootfs.sh"
    [ -x "$GET_ROOTFS" ] || { echo "ERROR: $GET_ROOTFS not found"; exit 1; }
    "$GET_ROOTFS"
fi

##############################################################################
# 2. Install Go + base packages in the chroot (BusyBox tar / xzcat only)
##############################################################################
echo "[*] Installing Go ${GO_VER} and build deps in chroot"
in_chroot "
set -e
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y git wget ca-certificates build-essential

# install Go if not already
[ -x /usr/local/go/bin/go ] || (
  cd /tmp &&
  wget -q ${GO_URL} &&
  tar -C /usr/local -xzf go${GO_VER}.linux-arm64.tar.gz
)
export PATH=/usr/local/go/bin:\$PATH

##############################################################################
# 3. Clone mediamtx and prepare assets (go generate does the downloads)
##############################################################################
cd /root
rm -rf mediamtx
git clone --depth 1 https://github.com/bluenviron/mediamtx.git
cd mediamtx
git describe --tags --always > VERSION
go generate ./...            # downloads hls.js and rpicamera helper, embeds

##############################################################################
# 4. Build fully-static binary
##############################################################################
CGO_ENABLED=0 go build -trimpath -ldflags '-s -w' -o mediamtx .
strip mediamtx
cp mediamtx /mediamtx-ready
"

##############################################################################
# 5. Copy binary to Yocto host
##############################################################################
echo "[*] Installing $MEDI_BIN_OUT"
cp "$ROOTFS/mediamtx-ready" "$MEDI_BIN_OUT"
chmod 755 "$MEDI_BIN_OUT"
echo "[OK] Static mediamtx installed:"
"$MEDI_BIN_OUT" --version || true

##############################################################################
# 6. PATH hint for non-login sudo shells
##############################################################################
echo
echo "NOTE: If 'mediamtx' is still not found in non-login shells (e.g. 'sudo su'),"
echo "add /usr/local/bin to sudoers secure_path or use 'sudo -i'."
