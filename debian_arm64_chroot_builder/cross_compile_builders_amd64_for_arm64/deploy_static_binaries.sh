#!/usr/bin/env bash
##############################################################################
# push_and_install.sh
#   • Copies ffmpeg + mediamtx to Portenta-X8 and installs them in /usr/local/bin
#   • Remote user / sudo password are both “fio”
##############################################################################
set -euo pipefail

REMOTE_USER=fio
REMOTE_HOST=10.0.0.2
REMOTE_PASS=fio

FFMPEG_LOCAL="ffmpeg-arm64-static/bin/ffmpeg"
MEDIAMTX_LOCAL="mediamtx-arm64-static/bin/mediamtx"

STAGING_DIR="/tmp"            # writable by normal users
INSTALL_DIR="/usr/local/bin"  # root-only

say(){ printf '\033[1;36m[*] %s\033[0m\n' "$*"; }
die(){ printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }

# ── 1. Preconditions ────────────────────────────────────────────────────────
[[ -f $FFMPEG_LOCAL ]]   || die "Missing $FFMPEG_LOCAL"
[[ -f $MEDIAMTX_LOCAL ]] || die "Missing $MEDIAMTX_LOCAL"

if ! command -v sshpass >/dev/null 2>&1; then
  say "Installing sshpass (sudo required)"
  sudo apt-get -qq update
  sudo apt-get -qq install --yes --no-install-recommends sshpass
fi

# ── 2. Stage files to /tmp on the Portenta (shows progress) ─────────────────
say "Copying binaries to ${REMOTE_HOST}:${STAGING_DIR}"
sshpass -p "$REMOTE_PASS" \
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      "$FFMPEG_LOCAL" "$MEDIAMTX_LOCAL" \
      "${REMOTE_USER}@${REMOTE_HOST}:${STAGING_DIR}/"

# ── 3. Elevate with sudo (password supplied via stdin) and install ──────────
say "Installing into ${INSTALL_DIR} via sudo"
sshpass -p "$REMOTE_PASS" \
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -tt "${REMOTE_USER}@${REMOTE_HOST}" <<EOF
echo "$REMOTE_PASS" | sudo -S sh -c '
  install -m 755 ${STAGING_DIR}/ffmpeg   ${INSTALL_DIR}/ffmpeg &&
  install -m 755 ${STAGING_DIR}/mediamtx ${INSTALL_DIR}/mediamtx &&
  rm -f ${STAGING_DIR}/ffmpeg ${STAGING_DIR}/mediamtx &&
  echo "Installed binaries:" &&
  ls -l ${INSTALL_DIR}/ffmpeg ${INSTALL_DIR}/mediamtx
'
EOF

say "Deployment finished."
