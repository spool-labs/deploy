#!/bin/bash
set -euo pipefail

echo "🛠 Setting up server..."

# Suppress interactive prompts
export DEBIAN_FRONTEND=noninteractive

# Update and upgrade packages
apt update
apt -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    upgrade -y

# Install required packages
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

# 🌀 Install Rust
echo "📦 Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Add Rust to system-wide PATH
source "$HOME/.cargo/env"
echo 'source "$HOME/.cargo/env"' > /etc/profile.d/rust.sh
chmod +x /etc/profile.d/rust.sh

# 📦 Install tapedrive-cli from crates.io
echo "📦 Installing tapedrive-cli from crates.io..."
cargo install tapedrive-cli

# Create app directory and symlink binary
mkdir -p ~/apps/tapedrive
ln -sf ~/.cargo/bin/tapedrive ~/apps/tapedrive/tapedrive

# Ensure Solana config directory exists
mkdir -p ~/.config/solana

# Enable nginx
systemctl enable --now nginx

echo "✅ Setup complete!"

