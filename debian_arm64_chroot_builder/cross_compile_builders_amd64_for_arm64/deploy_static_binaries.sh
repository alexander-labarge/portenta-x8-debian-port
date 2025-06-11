#!/usr/bin/env bash
##############################################################################
# push_and_install.sh
#   • Copies ffmpeg + mediamtx to Portenta-X8 and installs them in /usr/local/bin
#   • Auth user: fio   • Password: fio
##############################################################################
set -euo pipefail

REMOTE_USER=fio
REMOTE_HOST=10.0.0.2
REMOTE_PASS=fio

FFMPEG_LOCAL="ffmpeg-arm64-static/bin/ffmpeg"
MEDIAMTX_LOCAL="mediamtx-arm64-static/bin/mediamtx"
STAGING_DIR="/tmp"               # writable by normal users
INSTALL_DIR="/usr/local/bin"     # needs root

say() { printf '\033[1;36m[*] %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }

# ── 1. Preconditions ────────────────────────────────────────────────────────
[[ -f $FFMPEG_LOCAL ]]   || die "Missing $FFMPEG_LOCAL"
[[ -f $MEDIAMTX_LOCAL ]] || die "Missing $MEDIAMTX_LOCAL"

if ! command -v sshpass >/dev/null 2>&1; then
  say "Installing sshpass (sudo required)"
  sudo apt-get -qq update
  sudo apt-get -qq install --yes --no-install-recommends sshpass
fi

# ── 2. Stage files to /tmp on the Portenta ──────────────────────────────────
say "Copying binaries to ${REMOTE_HOST}:${STAGING_DIR}"
sshpass -p "$REMOTE_PASS" \
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      "$FFMPEG_LOCAL" "$MEDIAMTX_LOCAL" \
      "${REMOTE_USER}@${REMOTE_HOST}:${STAGING_DIR}/"

# ── 3. Use sudo remotely to install and clean up ────────────────────────────
say "Installing into ${INSTALL_DIR} with sudo"
sshpass -p "$REMOTE_PASS" \
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      "${REMOTE_USER}@${REMOTE_HOST}" <<'EOSSH'
set -e
sudo install -m 755 /tmp/ffmpeg   /usr/local/bin/ffmpeg
sudo install -m 755 /tmp/mediamtx /usr/local/bin/mediamtx
sudo rm -f /tmp/ffmpeg /tmp/mediamtx
echo "Done — binaries in /usr/local/bin:"
ls -l /usr/local/bin/{ffmpeg,mediamtx}
EOSSH

say "Deployment finished."
