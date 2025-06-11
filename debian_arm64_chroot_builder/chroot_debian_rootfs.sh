#!/bin/sh
# chroot_debian_rootfs.sh  –  Enter/leave the Debian Bookworm rootfs
# Works on stock Portenta-X8 Yocto (BusyBox only).

set -eu

ROOTFS_DIR="${ROOTFS_DIR:-/opt/bookworm-rootfs}"

# ---- sanity checks --------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root." >&2
    exit 1
fi
if [ ! -d "$ROOTFS_DIR" ]; then
    echo "Directory $ROOTFS_DIR not found (did the rootfs extract?)." >&2
    exit 1
fi

# ---- mount helpers --------------------------------------------------------
mp() { mountpoint -q "$ROOTFS_DIR/$1"; }          # test
mb() {                                           # bind-mount
    if ! mp "$1"; then
        [ -d "$ROOTFS_DIR/$1" ] || mkdir -p "$ROOTFS_DIR/$1"
        mount -o bind "$2" "$ROOTFS_DIR/$1"
    fi
}

echo "[*] Binding virtual filesystems"
mount -t proc proc    "$ROOTFS_DIR/proc"         2>/dev/null || true
mount -t sysfs sys    "$ROOTFS_DIR/sys"          2>/dev/null || true
mb dev   /dev
mb dev/pts /dev/pts
mb run   /run

# ---- enter chroot ---------------------------------------------------------
echo "[*] Entering chroot; type 'exit' or Ctrl-D to leave"
if [ -x "$ROOTFS_DIR/bin/bash" ]; then
    chroot "$ROOTFS_DIR" /bin/bash
else
    chroot "$ROOTFS_DIR" /bin/sh
fi

# ---- cleanup --------------------------------------------------------------
echo "[*] Cleaning up mounts"
umount -l "$ROOTFS_DIR/run"      2>/dev/null || true
umount -l "$ROOTFS_DIR/dev/pts"  2>/dev/null || true
umount -l "$ROOTFS_DIR/dev"      2>/dev/null || true
umount -l "$ROOTFS_DIR/sys"      2>/dev/null || true
umount -l "$ROOTFS_DIR/proc"     2>/dev/null || true
echo "[OK] All done."
