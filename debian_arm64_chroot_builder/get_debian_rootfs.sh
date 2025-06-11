#!/bin/sh
# get_debian_rootfs.sh  –  Fetch and unpack Debian Bookworm rootfs on Portenta X8
# BusyBox-only; no curl, no TLS, uses xzcat for extraction.

set -eu

# ---------------------------------------------------------------------------
DEB_REL="bookworm"
ARCH="arm64"
BASE_URL="http://images.linuxcontainers.org/images/debian/${DEB_REL}/${ARCH}/default"
ROOTFS_DIR="/opt/${DEB_REL}-rootfs"
TMP="/tmp/rootfs.tar.xz"
# ---------------------------------------------------------------------------

echo "[*] Creating target directory ${ROOTFS_DIR}"
mkdir -p "${ROOTFS_DIR}"

echo "[*] Finding latest rootfs.tar.xz under ${BASE_URL}"
# BusyBox wget prints page to stdout with -O -
LATEST_DIR=$(wget -qO- "${BASE_URL}/" \
  | grep -o '[0-9]\{8\}_[0-9]\{2\}:[0-9]\{2\}' \
  | sort | tail -n1)

if [ -z "${LATEST_DIR}" ]; then
  echo "ERROR: could not discover latest build directory" >&2
  exit 1
fi

ENC_DIR=$(printf '%s\n' "${LATEST_DIR}" | sed 's/:/%3A/')
TARBALL_URL="${BASE_URL}/${ENC_DIR}/rootfs.tar.xz"

echo "[*] Downloading ${TARBALL_URL}"
wget -q -O "${TMP}" "${TARBALL_URL}"

echo "[*] Extracting to ${ROOTFS_DIR}"
xzcat "${TMP}" | tar -xf - -C "${ROOTFS_DIR}"
rm -f "${TMP}"

echo "[*] Copying DNS resolver"
cp /etc/resolv.conf "${ROOTFS_DIR}/etc/"

echo "[*] Writing HTTP APT mirrors"
cat > "${ROOTFS_DIR}/etc/apt/sources.list" <<EOF
deb http://deb.debian.org/debian ${DEB_REL} main contrib non-free-firmware
deb http://deb.debian.org/debian ${DEB_REL}-updates main contrib non-free-firmware
deb http://security.debian.org/debian-security ${DEB_REL}-security main contrib non-free-firmware
EOF

echo "[OK] Debian rootfs ready at ${ROOTFS_DIR}"
echo "Next:  sudo ./chroot_debian_rootfs.sh"
