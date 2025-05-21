#!/usr/bin/env bash
set -euo pipefail

# build-macos.sh — Build and package tapedrive for macOS (x86_64 & arm64)
# Usage: ./build-macos.sh [--tag <tag>] [--out-dir <dir>]

# ── 1) Update & install OS dependencies ───────────────────────────────────────
if ! command -v brew >/dev/null; then
  echo "Homebrew not found. Please install Homebrew first: https://brew.sh/"
  exit 1
fi

#brew update
#brew install git curl pkg-config openssl rustup-init

# ── 2) Prepare environment ────────────────────────────────────────────────────
cwd="$(pwd)"

# ── 3) Parse arguments ────────────────────────────────────────────────────────
tag="latest"
out_dir="$cwd/dist"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      tag="$2"; shift 2;;
    --out-dir)
      if [[ "$2" = /* ]]; then
        out_dir="$2"
      else
        out_dir="$cwd/$2"
      fi
      shift 2;;
    *)
      echo "Usage: $0 [--tag <tag>] [--out-dir <dir>]"
      exit 1;;
  esac
done
mkdir -p "$out_dir"

# ── 4) Determine release tag ─────────────────────────────────────────────────
echo "🔍  Fetching latest release tag..."
if [[ "$tag" == "latest" ]]; then
  tag=$(curl -sSf https://api.github.com/repos/tapedrive-io/tape/releases/latest \
    | grep '"tag_name":' | head -n1 | cut -d '"' -f4)
fi
info_tag="$tag"
echo "📦 Building tapedrive $info_tag for macOS targets"

# ── 5) Install Rust toolchain & targets ───────────────────────────────────────
if ! command -v rustup >/dev/null; then
  rustup-init -y --no-modify-path
  source "$HOME/.cargo/env"
fi
rustup target add x86_64-apple-darwin aarch64-apple-darwin

# ── 6) Prepare source directory ───────────────────────────────────────────────
if [[ -f "$cwd/Cargo.toml" ]]; then
  build_dir="$cwd"
else
  echo "📥 Source not found; cloning tapedrive $info_tag..."
  build_dir=$(mktemp -d)
  trap 'rm -rf "$build_dir"' EXIT
  git clone --branch "$info_tag" --depth 1 https://github.com/tapedrive-io/tape.git "$build_dir"
fi

# ── 7) Build & package for each target ────────────────────────────────────────
echo "🔨 Entering build directory: $build_dir"
cd "$build_dir"

targets=(
  "x86_64-apple-darwin"
  "aarch64-apple-darwin"
)
for tgt in "${targets[@]}"; do
  echo "🔧 Building for $tgt..."
  export OPENSSL_DIR="$(brew --prefix openssl)"
  cargo build --release --target $tgt

  bin_src="target/$tgt/release/tapedrive"
  if [[ ! -f "$bin_src" ]]; then
    echo "Error: binary not found at $bin_src" >&2
    exit 1
  fi

  # convert e.g. x86_64-apple-darwin -> x86_64-darwin
  arch_name="${tgt/-apple-/-}"
  pkg_dir="$out_dir/tapedrive-$arch_name"="$out_dir/tapedrive-$arch_name"
  rm -rf "$pkg_dir" && mkdir -p "$pkg_dir"
  cp "$bin_src" "$pkg_dir/"
  chmod +x "$pkg_dir/tapedrive"

  tarball="$out_dir/tapedrive-$arch_name.tar.gz"
  echo "📦 Creating $tarball"
  tar -C "$pkg_dir" -czf "$tarball" tapedrive
done

# ── 8) Summary ───────────────────────────────────────────────────────────────
echo
echo "✅ Build complete. Artifacts in $out_dir:"
ls -1 "$out_dir"/*.tar.gz
