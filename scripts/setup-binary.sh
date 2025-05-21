#!/usr/bin/env bash
set -euo pipefail

echo "📦 Installing pre-built tapedrive binary…"

# Suppress interactive prompts
export DEBIAN_FRONTEND=noninteractive

# Update & install runtime dependencies
apt update
apt install -y curl tar nginx certbot python3-certbot-nginx

# Ensure target directory exists
mkdir -p ~/apps/tapedrive

# Fetch the latest release tag from GitHub API
echo "🔍 Querying GitHub for latest release…"
LATEST_JSON=$(curl -s https://api.github.com/repos/tapedrive-io/tape/releases/latest)
RELEASE_TAG=$(echo "$LATEST_JSON" | grep '"tag_name":' | head -n1 | cut -d '"' -f4)

if [ -z "$RELEASE_TAG" ]; then
  echo "❌ Failed to determine latest release tag"
  exit 1
fi
echo "✅ Found latest release: $RELEASE_TAG"

# Build the download URL for x86_64 Linux MUSL
TARBALL="tapedrive-x86_64-linux-musl.tar.gz"
DOWNLOAD_URL="https://github.com/tapedrive-io/tape/releases/download/${RELEASE_TAG}/${TARBALL}"

echo "⬇️  Downloading $TARBALL from $DOWNLOAD_URL…"
curl -L "$DOWNLOAD_URL" | tar -xz -C ~/apps/tapedrive

# Make sure the binary is executable
chmod +x ~/apps/tapedrive/tapedrive

# Enable & reload nginx (so your service templates can bind to it)
systemctl enable --now nginx

# Ensure Solana config directory exists
mkdir -p ~/.config/solana

echo "✅ Binary setup complete (installed $RELEASE_TAG)!"
