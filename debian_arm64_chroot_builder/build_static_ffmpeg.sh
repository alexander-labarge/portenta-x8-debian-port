#!/bin/sh
##############################################################################
# build_static_ffmpeg.sh  ·  Portenta-X8 (Yocto) one-shot builder
#   • Uses get_debian_rootfs.sh if /opt/bookworm-rootfs is missing
#   • Uses chroot_debian_rootfs.sh for every chrooted command
#   • Builds static x265, then fully-static FFmpeg (x264+x265+VPx+FDK-AAC)
#   • Installs finished binary to /usr/local/bin/ffmpeg on Yocto
##############################################################################
set -eu

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
GET_ROOTFS="$SELF_DIR/get_debian_rootfs.sh"
CHROOT_SH="$SELF_DIR/chroot_debian_rootfs.sh"
ROOTFS="/opt/bookworm-rootfs"
FFMPEG_OUT="/usr/local/bin/ffmpeg"
PKG_DIR="/usr/local/ffmpeg-static/lib/pkgconfig"
PKG_PATH="$PKG_DIR:/usr/local/ffmpeg-static/lib64/pkgconfig"

[ -x "$CHROOT_SH" ] || { echo "ERROR: $CHROOT_SH not found"; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }

##############################################################################
# Helper: run arbitrary command string inside chroot via your wrapper
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
# 2. Add non-free to sources.list (if not present)
##############################################################################
echo "[*] Ensuring contrib and non-free sections are enabled"
in_chroot "
sed -i 's/main contrib non-free-firmware/main contrib non-free non-free-firmware/' /etc/apt/sources.list
apt-get update
"

##############################################################################
# 3. Install build prerequisites
##############################################################################
echo "[*] Installing toolchain and dev libraries"
in_chroot "
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential git pkg-config yasm nasm cmake mercurial \
  libx264-dev libvpx-dev libfdk-aac-dev
"

##############################################################################
# 4. Build static x265
##############################################################################
echo "[*] Building static x265"
in_chroot "
mkdir -p /usr/local/src &&
cd /usr/local/src &&
git clone --depth 1 https://github.com/videolan/x265.git &&
mkdir x265/build && cd x265/build &&
cmake ../source -DCMAKE_INSTALL_PREFIX=/usr/local/ffmpeg-static \
      -DENABLE_SHARED=OFF -DENABLE_CLI=OFF &&
make -j\$(nproc) &&
make install
"

# Minimal pkg-config shim so FFmpeg can detect the static lib
echo "[*] Writing x265.pc shim"
in_chroot "
mkdir -p $PKG_DIR && cat > $PKG_DIR/x265.pc <<'ENDPC'
prefix=/usr/local/ffmpeg-static
exec_prefix=${prefix}
libdir=${prefix}/lib
includedir=${prefix}/include
Name: x265
Description: H.265/HEVC encoder library (static)
Version: 3.6
Libs: -L${libdir} -lx265
Libs.private: -lstdc++ -lm -lpthread -ldl
Cflags: -I${includedir}
ENDPC
"

##############################################################################
# 5. Build fully-static FFmpeg
##############################################################################
echo "[*] Building fully-static FFmpeg (grab coffee…)"
in_chroot "
export PKG_CONFIG_PATH=$PKG_PATH
cd /root &&
git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git &&
cd ffmpeg &&
./configure \
  --prefix=/usr/local/ffmpeg-static \
  --pkg-config-flags='--static' \
  --extra-cflags='-static' --extra-ldflags='-static' \
  --extra-libs='-lpthread -lm' \
  --enable-gpl --enable-nonfree \
  --enable-libx264 --enable-libx265 --enable-libvpx --enable-libfdk_aac \
  --disable-shared --enable-static &&
make -j\$(nproc) &&
strip ffmpeg &&
cp ffmpeg /ffmpeg-ready
"

##############################################################################
# 6. Install binary on Yocto host
##############################################################################
echo "[*] Installing $FFMPEG_OUT"
cp "$ROOTFS/ffmpeg-ready" "$FFMPEG_OUT"
chmod 755 "$FFMPEG_OUT"
# Yocto host, as root
cat > /etc/profile.d/local-bin.sh <<'EOF'
# Add /usr/local/bin from overlay (/var/usrlocal/bin) to default search path
export PATH=/usr/local/bin:$PATH
EOF
chmod 644 /etc/profile.d/local-bin.sh
# Ensure the new profile is sourced
if [ -f /etc/profile ]; then
    . /etc/profile
else
    echo "WARNING: /etc/profile not found, please source it manually"
fi
echo "[OK] Static FFmpeg installed – version:"
"$FFMPEG_OUT" -version | head -n 4
