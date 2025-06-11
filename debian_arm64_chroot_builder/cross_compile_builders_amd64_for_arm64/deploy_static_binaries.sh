#!/usr/bin/env bash
##############################################################################
# deploy_static_binaries.sh
#
# Pushes the freshly-built **ffmpeg** and **mediamtx** arm64 static binaries
# to a Portenta-X8 running the default Yocto image and installs them under
# /usr/local/bin (a bind-mount to the writable overlay).
#
# • Source host : Ubuntu 24.04 x86-64
# • Target host : fio@10.0.0.2  (password-less sudo enabled)
# • Binaries    : ffmpeg-arm64-static/bin/ffmpeg
#                 mediamtx-arm64-static/bin/mediamtx
##############################################################################
set -euo pipefail

# ── CONFIG ──────────────────────────────────────────────────────────────────
REMOTE=fio@10.0.0.2
PASS=fio                     # ssh password for user fio
STAGING=/tmp                 # always writable
DEST=/usr/local/bin          # bind-mount to /var/rootdirs/usr/local/bin

FFMPEG=ffmpeg-arm64-static/bin/ffmpeg
MEDI=mediamtx-arm64-static/bin/mediamtx
# ────────────────────────────────────────────────────────────────────────────

say() { printf '\033[1;36m[*] %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }

# ── 1. Local pre-flight ------------------------------------------------------
[[ -f $FFMPEG ]]   || die "Missing $FFMPEG"
[[ -f $MEDI   ]]   || die "Missing $MEDI"

command -v sshpass >/dev/null 2>&1 || {
  say "Installing sshpass"
  sudo apt-get -qq update && sudo apt-get -qq install -y sshpass
}

# ── 2. Copy binaries to the target ------------------------------------------
say "Copying binaries to $REMOTE:$STAGING/"
sshpass -p "$PASS" \
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      "$FFMPEG" "$MEDI" "$REMOTE:$STAGING/"

# ── 3. Promote + verify on the target ---------------------------------------
say "Installing to $DEST and verifying versions"
sshpass -p "$PASS" \
  ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE" \
"set -e
sudo install -d -m 755 '$DEST'
sudo install -m 755 '$STAGING/ffmpeg'   '$DEST/ffmpeg'
sudo install -m 755 '$STAGING/mediamtx' '$DEST/mediamtx'
sudo rm -f '$STAGING/ffmpeg' '$STAGING/mediamtx'

echo
echo '✔  Installed files:'; ls -lh '$DEST/ffmpeg' '$DEST/mediamtx'
echo
echo '✔  Runtime version checks:'
'$DEST/ffmpeg' -version | head -n 1
'$DEST/mediamtx' --version || true
"

say "Deployment complete."
