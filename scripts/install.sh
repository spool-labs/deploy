#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# tapedrive installer — https://github.com/tapedrive-io/tape
# Usage: curl -fsSL https://tapedrive.io/install.sh | bash [<version>]
# If no version is given, installs latest release.
# ──────────────────────────────────────────────────────────────────────────────

# ─── Platform & OS Detection ─────────────────────────────────────────────────
platform=$(uname -ms)
if [[ ${OS:-} = Windows_NT ]]; then
  if [[ $platform != MINGW64* ]]; then
    powershell -c "irm https://tapedrive.io/install.ps1|iex"
    exit $?
  fi
fi

# ─── Colors ─────────────────────────────────────────────────────────────────
Color_Off=''
Red=''
Green=''
Dim=''       # faint text
Bold_White=''
Bold_Green=''
if [[ -t 1 ]]; then
  Color_Off='\033[0m'
  Red='\033[0;31m'
  Green='\033[0;32m'
  Dim='\033[0;2m'
  Bold_White='\033[1m'
  Bold_Green='\033[1;32m'
fi

# ─── Helper functions ─────────────────────────────────────────────────────────
error()   { echo -e "${Red}error${Color_Off}:" "$@" >&2; exit 1; }
info()    { echo -e "${Dim}$@${Color_Off}"; }
info_bold(){ echo -e "${Bold_White}$@${Color_Off}"; }
success(){ echo -e "${Green}$@${Color_Off}"; }

# Simplify paths to ~
tildify() {
  if [[ $1 = $HOME/* ]]; then
    echo "~/${1#$HOME/}"
  else
    echo "$1"
  fi
}

# ─── Prerequisites ───────────────────────────────────────────────────────────
command -v curl >/dev/null || error 'curl is required'
command -v tar  >/dev/null || error 'tar is required'

# ─── Arguments ───────────────────────────────────────────────────────────────
if [[ $# -gt 1 ]]; then
  error 'Only one argument allowed: an optional release tag (e.g. "v1.2.3").'
fi

# ─── Determine release tag ────────────────────────────────────────────────────
if [[ $# -eq 1 ]]; then
  TAG="$1"
else
  info '🔍  Fetching latest release…'
  TAG=$(curl -sSf https://api.github.com/repos/tapedrive-io/tape/releases/latest \
    | grep '"tag_name":' | head -n1 | cut -d '"' -f4) \
    || error 'failed to fetch latest release'
fi
info_bold "⬇️  Installing tapedrive ${TAG}…"

# ─── Platform mapping & musl preference ────────────────────────────────────────
case $platform in
  'Darwin x86_64')              target=x86_64-darwin  ;;  
  'Darwin arm64')               target=aarch64-darwin  ;;  
  'Linux x86_64')               target=x86_64-linux-musl   ;;  
  'Linux arm64'|'Linux aarch64') target=aarch64-linux-musl ;;  
  'MINGW64'*)                   target=x86_64-windows ;;  
  *)                            error "unsupported platform: $platform" ;;  
esac

# # Alpine musl on Linux
# if [[ $target == x86_64-linux ]]; then
#   if [[ -f /etc/alpine-release ]]; then
#     target=x86_64-linux-musl
#   fi
# fi

# Rosetta on macOS
if [[ $target == x86_64-darwin ]]; then
  if [[ $(sysctl -n sysctl.proc_translated 2>/dev/null) == 1 ]]; then
    target=aarch64-darwin
    info "Running under Rosetta 2, using $target build"
  fi
fi

# ─── Download & extract ───────────────────────────────────────────────────────
BUCKET="https://github.com/tapedrive-io/tape/releases/download"
ARCHIVE="tapedrive-${target}.tar.gz"
URI="$BUCKET/$TAG/$ARCHIVE"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

info "⬇️  Downloading ${ARCHIVE}…"
curl --fail --location --progress-bar --output "$tmp/$ARCHIVE" "$URI" \
  || error "failed to download $ARCHIVE"

install_dir="${TAPE_INSTALL:-$HOME/.tapedrive}"
mkdir -p "$install_dir/bin" \
  || error "failed to create install directory"
tar -xzf "$tmp/$ARCHIVE" -C "$install_dir/bin" \
  || error "failed to extract archive"

# ─── Post-install ─────────────────────────────────────────────────────────────
exe="$install_dir/bin/tapedrive"
chmod +x "$exe" || error "failed to make executable"
success "✅ tapedrive ${TAG} installed to $Bold_Green$(tildify "$exe")${Color_Off}"

# ─── Add to PATH ──────────────────────────────────────────────────────────────
install_env=TAPE_INSTALL
commands=(
  "export $install_env=\"$install_dir\""
  "export PATH=\"\$$install_env/bin:\$PATH\""
)

refresh_cmd=''
apply_to() {
  local rc="$1"
  if [[ -w $rc ]]; then
    {
      echo -e "\n# tapedrive"
      for c in "${commands[@]}"; do echo "$c"; done
    } >> "$rc"
    info "Added to PATH in $rc"
    refresh_cmd="source $rc"
    return 0
  fi
  return 1
}
case "$(basename "${SHELL:-}")" in
  fish) apply_to "$HOME/.config/fish/config.fish" ;;  
  zsh)  apply_to "$HOME/.zshrc" ;;  
  bash) for rc in "$HOME/.bashrc" "$HOME/.bash_profile"; do apply_to "$rc" && break; done ;;  
esac

# ─── Final hints ──────────────────────────────────────────────────────────────
echo
if [[ -n $refresh_cmd ]]; then
  info "Run '$refresh_cmd' to start using tapedrive"
else
  echo 'Add to your shell profile:'
  for c in "${commands[@]}"; do info_bold "  $c"; done
fi

echo
info_bold "Run 'tapedrive --help' to get started"
