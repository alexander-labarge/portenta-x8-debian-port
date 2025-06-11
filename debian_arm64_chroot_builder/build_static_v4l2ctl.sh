#!/bin/sh
##############################################################################
# build_static_v4l2ctl.sh · Portenta-X8 Yocto
#   • Runs everything that needs tool-chains inside Debian chroot
#   • Builds static libjpeg-turbo (≈ 500 kB) – no shared libs produced
#   • Builds v4l2-ctl from gjasny/v4l-utils completely static
#   • Copies single binary to /usr/local/bin/v4l2-ctl on Yocto host
#   • Adds /usr/local/bin to PATH for login + sudo shells (first run only)
##############################################################################
set -eu

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROOT_SH="$SELF_DIR/chroot_debian_rootfs.sh"
ROOTFS="/opt/bookworm-rootfs"

[ -x "$CHROOT_SH" ] || { echo "ERROR: chroot helper not found"; exit 1; }
[ "$(id -u)" -ne 0 ] && { echo "run as root"; exit 1; }

run_in_chroot() {
  printf '%s\nexit\n' "$1" | ROOTFS_DIR="$ROOTFS" "$CHROOT_SH" >/dev/null
}

##############################################################################
echo "[*] Building fully-static v4l2-ctl in chroot"
run_in_chroot '
set -eu
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential git pkg-config meson ninja-build gettext \
  wget curl xz-utils zlib1g-dev

########################################################################
# 1. build static libjpeg-turbo
########################################################################
cd /tmp
LIBJPEG_VER=3.0.2
curl -sLO https://downloads.sourceforge.net/project/libjpeg-turbo/${LIBJPEG_VER}/libjpeg-turbo-${LIBJPEG_VER}.tar.gz
tar -xf libjpeg-turbo-${LIBJPEG_VER}.tar.gz
cd libjpeg-turbo-${LIBJPEG_VER}
cmake -G"Unix Makefiles" -DCMAKE_POSITION_INDEPENDENT_CODE=OFF \
      -DENABLE_SHARED=OFF -DENABLE_STATIC=ON \
      -DCMAKE_INSTALL_PREFIX=/usr/local/static .
make -j$(nproc)
make install      # installs libjpeg.a + jpeglib.h into /usr/local/static

export PKG_CONFIG_PATH=/usr/local/static/lib/pkgconfig:$PKG_CONFIG_PATH
echo "[chroot] static libjpeg-turbo installed"

########################################################################
# 2. clone and build static v4l2-ctl
########################################################################
cd /tmp
git clone --depth 1 https://github.com/gjasny/v4l-utils.git
cd v4l-utils

# Meson will now pick up our static libjpeg
export CFLAGS="-static"
export CXXFLAGS="-static -static-libstdc++ -static-libgcc"
export LDFLAGS="-static -static-libstdc++ -static-libgcc"

meson setup build -Ddefault_library=static >/dev/null
meson compile -C build v4l2-ctl >/dev/null

BIN=$(find build -type f -name v4l2-ctl | head -n1)
strip "$BIN"
cp "$BIN" /tmp/v4l2-ctl-static
echo "[chroot] /tmp/v4l2-ctl-static ready – size $(du -h /tmp/v4l2-ctl-static | cut -f1)"
'

##############################################################################
echo "[*] Copying static binary to Yocto host"
install -Dm755 "$ROOTFS/tmp/v4l2-ctl-static" /usr/local/bin/v4l2-ctl

# one-time PATH tweaks
if ! grep -q /usr/local/bin /etc/profile.d/local-bin.sh 2>/dev/null; then
  echo 'export PATH=/usr/local/bin:$PATH' > /etc/profile.d/local-bin.sh
fi
if ! sudo -V | grep -q /usr/local/bin; then
  sed -i 's|secure_path="|secure_path="/usr/local/bin:|' /etc/sudoers || true
fi

echo "[OK] Static v4l2-ctl installed:"
file /usr/local/bin/v4l2-ctl
echo "Open a new shell and run  v4l2-ctl --list-devices"
