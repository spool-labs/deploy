#!/usr/bin/env bash
set -euo pipefail

echo "🛠  Setting up server..."
export DEBIAN_FRONTEND=noninteractive

# ── 1) Update & install OS dependencies ───────────────────────────────────────
apt update
apt -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
  upgrade -y

apt install -y \
  build-essential \
  clang \
  pkg-config \
  libzstd-dev \
  libssl-dev \
  curl \
  git \
  nginx \
  certbot \
  python3-certbot-nginx

# ── 2) Install Rust toolchain ─────────────────────────────────────────────────
echo "📦  Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
# Source for current shell
. "$HOME/.cargo/env"
# Persist for future shells
echo '. "$HOME/.cargo/env"' > /etc/profile.d/rust.sh
chmod +x /etc/profile.d/rust.sh

# ── 3) Add the MUSL target ────────────────────────────────────────────────────
rustup target add x86_64-unknown-linux-musl

# ── 4) Fetch a prebuilt MUSL cross-toolchain ─────────────────────────────────
echo "⚙️  Installing MUSL cross-compiler..."
CROSS_DIR=/opt/x-tools
mkdir -p "$CROSS_DIR"

curl -fsSL https://musl.cc/x86_64-linux-musl-cross.tgz \
  | tar xz -C "$CROSS_DIR"

# ── 5) Wire it into PATH & configure Cargo linker ─────────────────────────────
export PATH="$CROSS_DIR/x86_64-linux-musl-cross/bin:$PATH"
export CC_x86_64_unknown_linux_musl="x86_64-linux-musl-gcc"
export CXX_x86_64_unknown_linux_musl="x86_64-linux-musl-g++"
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER="x86_64-linux-musl-g++"

# ── 6) Clone and build the static binary ─────────────────────────────────────
echo "🔧  Building static tapedrive binary..."
BUILD_DIR=$(mktemp -d /tmp/tape-build-XXXX)
git clone --depth 1 https://github.com/tapedrive-io/tape.git "$BUILD_DIR"
pushd "$BUILD_DIR" >/dev/null

# Ensure build scripts run on host (no global static flags)
unset RUSTFLAGS

# Apply static CRT only for the MUSL target
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_RUSTFLAGS="-C target-feature=+crt-static"

# Build the release for MUSL target; linker and rustflags pick cross toolchain
cargo build --release --target x86_64-unknown-linux-musl
popd >/dev/null

# ── 7) Strip & package the artifact ──────────────────────────────────────────
ARTIFACT_DIR="$HOME/build/tapedrive"
mkdir -p "$ARTIFACT_DIR"

cp "$BUILD_DIR/target/x86_64-unknown-linux-musl/release/tapedrive" "$ARTIFACT_DIR/"
x86_64-linux-musl-strip "$ARTIFACT_DIR/tapedrive"

cd "$ARTIFACT_DIR"
tar czf tapedrive-x86_64-linux-musl.tar.gz tapedrive
