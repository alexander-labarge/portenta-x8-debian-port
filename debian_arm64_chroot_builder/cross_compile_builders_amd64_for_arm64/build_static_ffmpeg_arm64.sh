#!/usr/bin/env bash
##############################################################################
# build_ffmpeg_arm64_static.sh
#   • Host  : Ubuntu 24.04 x86-64
#   • Output: ffmpeg-arm64-static/bin/ffmpeg (fully static, AArch64, libx265)
##############################################################################
set -euo pipefail

say(){ printf '\033[1;36m[*] %s\033[0m\n' "$*"; }
ok(){  printf '\033[1;32m    → %s\033[0m\n' "$*"; }
die(){ printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }

# ── 1. Host sanity ──────────────────────────────────────────────────────────
source /etc/lsb-release
[[ $DISTRIB_ID == Ubuntu && $DISTRIB_RELEASE == 24.04 ]] || \
  die "Run this script on Ubuntu 24.04."

# ── 2. Packages ─────────────────────────────────────────────────────────────
say "Installing build dependencies"
sudo apt-get -qq update
sudo apt-get -qq install --yes --no-install-recommends \
  build-essential git pkg-config yasm nasm cmake ninja-build \
  autoconf automake libtool gettext autopoint wget curl xz-utils \
  crossbuild-essential-arm64 qemu-user-static ca-certificates

# ── 3. musl tool-chain (brings static libc) ─────────────────────────────────
MUSL_URL="https://musl.cc/aarch64-linux-musl-cross.tgz"
MUSL_DIR="$PWD/musl-cross"
if [[ ! -d $MUSL_DIR ]]; then
  say "Fetching musl-cross tool-chain"
  wget -qO- "$MUSL_URL" | tar -xz
  mv aarch64-linux-musl-cross "$MUSL_DIR"
fi
export PATH="$MUSL_DIR/bin:$PATH"
CROSS=aarch64-linux-musl
ok "$($CROSS-gcc -dumpmachine)  gcc $($CROSS-gcc -dumpversion)"

# ── 4. Install prefix ───────────────────────────────────────────────────────
PREFIX="$PWD/ffmpeg-arm64-static"
rm -rf "$PREFIX"; mkdir -p "$PREFIX"/{bin,lib/pkgconfig}

# ── 5. Build static x265 ────────────────────────────────────────────────────
say "Building x265"
git clone --quiet --depth 1 https://github.com/videolan/x265.git
cmake -S x265/source -B x265/build \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
  -DCMAKE_C_COMPILER=$CROSS-gcc \
  -DCMAKE_CXX_COMPILER=$CROSS-g++ \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DENABLE_ASSEMBLY=OFF > /dev/null
cmake --build   x265/build -j"$(nproc)" > /dev/null
cmake --install x265/build              > /dev/null
ok "libx265.a installed"

# ── 6. Create corrected x265.pc shim ────────────────────────────────────────
cat > "$PREFIX/lib/pkgconfig/x265.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: x265
Description: H.265/HEVC encoder (static)
Version: 3.6

# static link flags include C++ runtime, math, pthread
Libs: -L\${libdir} -lx265 -lstdc++ -lm -lpthread
Cflags: -I\${includedir}
EOF

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

# ── 7. Static-link probe (links with x265) ──────────────────────────────────
say "Static link sanity check"
cat > test.c << 'EOF'
int main(){return 0;}
EOF

if $CROSS-gcc -static test.c $(pkg-config --static --libs x265) -o test; then
  rm -f test.c test
  ok "tool-chain can link hello + libx265.a"
else
  rm -f test.c
  die "Static link sanity check failed"
fi

# ── 8. Build FFmpeg (100 % static) ──────────────────────────────────────────
say "Building FFmpeg"
git clone --quiet --depth 1 https://git.ffmpeg.org/ffmpeg.git
pushd ffmpeg > /dev/null

# ensure x265 is visible
[[ -n $(pkg-config --modversion x265 2>/dev/null) ]] || \
  die "x265.pc not visible inside ffmpeg dir!"

pkg_config=pkg-config \
./configure \
  --prefix="$PREFIX" \
  --cross-prefix=$CROSS- \
  --arch=aarch64 --target-os=linux \
  --pkg-config-flags="--static" \
  --disable-debug --disable-doc \
  --disable-shared --enable-static \
  --enable-gpl --enable-nonfree \
  --enable-libx265 \
  --extra-cflags="-I$PREFIX/include -static" \
  --extra-ldflags="-L$PREFIX/lib -static" \
  --extra-libs="-lpthread -lm"

make -j"$(nproc)" > /dev/null
$CROSS-strip ffmpeg
cp ffmpeg "$PREFIX/bin/"
popd > /dev/null

# ── 9. Result ───────────────────────────────────────────────────────────────
ok "Finished:"
file "$PREFIX/bin/ffmpeg"
"$PREFIX/bin/ffmpeg" -version | head -n 4
