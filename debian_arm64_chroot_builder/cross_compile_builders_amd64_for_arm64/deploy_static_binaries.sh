#!/usr/bin/env bash
##############################################################################
# deploy_static_binaries.sh
#
# Pushes fully-static ARM64 binaries (ffmpeg, mediamtx, dockerd, docker)
# to a Portenta-X8 (Yocto), installs them under /usr/local/bin, and
# configures + enables systemd units.
##############################################################################
set -euo pipefail

# ── CONFIG ──────────────────────────────────────────────────────────────────
REMOTE=fio@10.0.0.2   # Portenta X8 address (password-less sudo enabled)
PASS=fio              # SSH password (adjust!)
STAGING=/tmp          # writable on target
DEST=/usr/local/bin   # bind-mounted overlay

FFMPEG=ffmpeg-arm64-static/bin/ffmpeg
MEDI=mediamtx-arm64-static/bin/mediamtx
DOCKD=docker-arm64-static/bin/dockerd
DOCKR=docker-arm64-static/bin/docker
# ────────────────────────────────────────────────────────────────────────────

say(){ printf '\033[1;36m[*] %s\033[0m\n' "$*"; }
die(){ printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }

# 1 Local sanity -----------------------------------------------------------
for BIN in "$FFMPEG" "$MEDI" "$DOCKD" "$DOCKR"; do
  [[ -f $BIN ]] || die "Missing $BIN – build step incomplete?"
done
command -v sshpass >/dev/null || {
  say "Installing sshpass";  sudo apt-get -qq update && sudo apt-get -qq install -y sshpass; }

# 2 Copy binaries ----------------------------------------------------------
say "Copying binaries → $REMOTE:$STAGING/"
sshpass -p "$PASS" scp -q \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$FFMPEG" "$MEDI" "$DOCKD" "$DOCKR" "$REMOTE:$STAGING/"

# 3 Remote install + service setup ----------------------------------------
say "Installing + configuring systemd on target"
sshpass -p "$PASS" \
ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE" <<'EOF'
set -e
STAGING=/tmp
DEST=/usr/local/bin
sudo install -d -m 755 "$DEST"

# ----- copy binaries --------------------------------------------------------
sudo install -m 755 "$STAGING/ffmpeg"   "$DEST/ffmpeg"
sudo install -m 755 "$STAGING/mediamtx" "$DEST/mediamtx"
sudo install -m 755 "$STAGING/dockerd"  "$DEST/dockerd"
sudo install -m 755 "$STAGING/docker"   "$DEST/docker"
sudo rm -f "$STAGING"/{ffmpeg,mediamtx,dockerd,docker}

# ----- docker.service -------------------------------------------------------
sudo tee /etc/systemd/system/docker.service >/dev/null <<'UNIT'
[Unit]
Description=Docker Engine (static build)
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/bin/dockerd \
          --host=unix:///var/run/docker.sock \
          --data-root=/usr/local/docker-data \
          --userland-proxy=false \
          --iptables=false \
          --ip-masq=false \
          --bridge=none
Restart=on-failure
RestartSec=5s
Delegate=yes
Environment=PATH=/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
UNIT

# ----- mediamtx.service (optional) -----------------------------------------
sudo tee /etc/systemd/system/mediamtx.service >/dev/null <<'UNIT'
[Unit]
Description=MediaMTX RTSP/RTP Server (static build)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/mediamtx /etc/mediamtx.yml
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

# ----- enable + start -------------------------------------------------------
sudo mkdir -p /usr/local/docker-data
sudo systemctl daemon-reload
sudo systemctl enable --now docker.service
sudo systemctl enable --now mediamtx.service   # comment if not needed

# ----- report ----------------------------------------------------------------
echo
echo '✔ Installed files:'; ls -lh "$DEST"/{ffmpeg,mediamtx,dockerd,docker}
echo
echo '✔ Version checks:'
"$DEST/ffmpeg" -version | head -n 1
"$DEST/mediamtx" --version || true
"$DEST/docker" --version
"$DEST/dockerd" --version | head -n 1
echo
echo '✔ Service state (first 6 lines):'
systemctl --no-pager --full status docker.service   | sed -n '1,6p'
systemctl --no-pager --full status mediamtx.service | sed -n '1,6p'
EOF

say "Deployment complete."
