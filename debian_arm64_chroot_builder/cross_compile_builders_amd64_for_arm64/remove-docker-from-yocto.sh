#!/usr/bin/env bash
set -euo pipefail

# remove-docker-from-yocto.sh
#   -s    stop & disable Docker services only
#   -r    stop, disable AND remove all Docker bits (default)

usage() {
  cat <<EOF
Usage: $0 [-s | -r] [-h]

  -s    stop & disable Docker only (won't delete binaries or data - appears non persistent)
  -r    stop, disable AND remove Docker binaries, units, and system services (default)
  -h    show this help and exit
EOF
  exit 1
}

# parse options
do_stop_only=false
do_remove=false

while getopts "srh" opt; do
  case "$opt" in
    s) do_stop_only=true ;;  
    r) do_remove=true ;;      
    h) usage ;;              
    *) usage ;;              
esac
done

# enforce mutually exclusive, default to remove
if $do_stop_only && $do_remove; then
  echo "ERROR: -s and -r are mutually exclusive." >&2
  usage
fi
if ! $do_stop_only && ! $do_remove; then
  do_remove=true
fi

# must be root
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run as root." >&2
  exit 1
fi

echo "[*] Remounting /usr read-write"
mountpoint -q /usr || { echo "ERROR: /usr not a mountpoint"; exit 1; }
mount -o remount,rw /usr

echo "[*] Stopping and disabling Docker services"
systemctl stop docker.socket docker.service || true
systemctl disable docker.service docker.socket || true
systemctl daemon-reload

if $do_stop_only; then
  echo "[✓] Docker services stopped & disabled."
  echo "[*] Remounting /usr read-only"
  mount -o remount,ro /usr
  exit 0
fi

# full removal
echo "[*] Removing Docker binaries"
for bin in /usr/bin/docker /usr/bin/docker-* /usr/bin/dockerd; do
  [[ -e $bin ]] && rm -f "$bin" && echo "   → removed $bin"
done

echo "[*] Removing systemd unit files"
for unit in docker.service docker.socket docker-proxy; do
  rm -f /usr/lib/systemd/system/${unit}* \
        /etc/systemd/system/${unit}* \
    && echo "   → removed unit ${unit}"
done

echo "[*] Purging Docker data directories"
for dir in /var/lib/docker /etc/docker /usr/lib/docker /usr/etc/docker; do
  [[ -e $dir ]] && rm -rf "$dir" && echo "   → removed $dir"
done

# only tweak fstab if an entry for /usr exists <- doesnt by default but android does so gonna keep here for now
if grep -qE '[[:space:]]/usr[[:space:]]' /etc/fstab; then
  echo "[*] Backing up and commenting out /usr line in /etc/fstab"
  cp -a /etc/fstab{,.bak}
  sed -i '/[[:space:]]\/usr[[:space:]]/ s@^@#@' /etc/fstab
  echo "   → backed up to /etc/fstab.bak and commented out"
else
  echo "[*] No separate /usr entry in /etc/fstab, skipping fstab update"
fi

echo "[*] Remounting /usr read-only"
mount -o remount,ro /usr

echo "[✓] Docker fully removed; /usr restored RO."
