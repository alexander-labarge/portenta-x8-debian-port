#!/usr/bin/env bash
##############################################################################
# deploy_static_binaries.sh
#
# Copies freshly-built arm64 **static binaries** from the build host
# (Ubuntu 24.04 x86-64) to a Portenta-X8 running its stock Yocto image,
# then installs them under /usr/local/bin (a bind-mount writable overlay).
#
#  PUSHED FILES
#    • ffmpeg-arm64-static/bin/ffmpeg
#    • mediamtx-arm64-static/bin/mediamtx
#    • docker-arm64-static/bin/dockerd
#    • docker-arm64-static/bin/docker
#
#  TARGET
#    • Host  : fio@10.0.0.2   (password-less sudo enabled)
#    • Dir   : /usr/local/bin (bind-mount to /var/rootdirs/… inside Yocto)
##############################################################################
set -euo pipefail

# ── CONFIG ──────────────────────────────────────────────────────────────────
REMOTE=fio@10.0.0.2
PASS=fio                     # SSH password for user fio (replace as needed)
STAGING=/tmp                 # always writable on the target
DEST=/usr/local/bin          # bind-mount overlay path

FFMPEG=ffmpeg-arm64-static/bin/ffmpeg
MEDI=mediamtx-arm64-static/bin/mediamtx
DOCKD=docker-arm64-static/bin/dockerd
DOCKR=docker-arm64-static/bin/docker
# ────────────────────────────────────────────────────────────────────────────

say(){ printf '\033[1;36m[*] %s\033[0m\n' "$*"; }
die(){ printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }

# ── 1. Local sanity checks ---------------------------------------------------
for BIN in "$FFMPEG" "$MEDI" "$DOCKD" "$DOCKR"; do
  [[ -f $BIN ]] || die "Missing $BIN – build step incomplete?"
done

command -v sshpass >/dev/null 2>&1 || {
  say "Installing sshpass"
  sudo apt-get -qq update && sudo apt-get -qq install -y sshpass
}

# ── 2. Copy binaries to target ----------------------------------------------
say "Copying binaries to $REMOTE:$STAGING/"
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$FFMPEG" "$MEDI" "$DOCKD" "$DOCKR" "$REMOTE:$STAGING/"

# ── 3. Promote + verify on target -------------------------------------------
say "Installing to $DEST and verifying"
sshpass -p "$PASS" \
ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE" <<'EOF'
set -e
STAGING=/tmp
DEST=/usr/local/bin
sudo install -d -m 755 "$DEST"

sudo install -m 755 "$STAGING/ffmpeg"   "$DEST/ffmpeg"
sudo install -m 755 "$STAGING/mediamtx" "$DEST/mediamtx"
sudo install -m 755 "$STAGING/dockerd"  "$DEST/dockerd"
sudo install -m 755 "$STAGING/docker"   "$DEST/docker"
sudo rm -f "$STAGING/ffmpeg" "$STAGING/mediamtx" "$STAGING/dockerd" "$STAGING/docker"

echo
echo '✔  Installed files:'
ls -lh "$DEST/ffmpeg" "$DEST/mediamtx" "$DEST/dockerd" "$DEST/docker"

echo
echo '✔  Runtime version checks (expect static ARM binaries):'
"$DEST/ffmpeg"   -version | head -n 1
"$DEST/mediamtx" --version || true
"$DEST/docker"   --version
"$DEST/dockerd"  --version | head -n 1 || true
EOF

say "Deployment complete."
