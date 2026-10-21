#!/usr/bin/env bash
# rebuild rubicon from nothing.
#
# the android terminal app re-provisions this guest from a cloud-init seed
# (/dev/vdb) and a rootfs backup (/dev/vdc -> /mnt/backup). when it does,
# everything outside /home/droid is reverted: apt packages, /nix, and the login
# shell in /etc/passwd, which the seed pins back to /usr/bin/bash. $HOME
# survives, and so does ~/.config/gh, so this script can authenticate to a
# private flake without a fresh login.
#
#   bash ~/Code/nix-config/hosts/rubicon-bootstrap.sh
#
# idempotent: safe to re-run.
set -euo pipefail

CHECKOUT="${CHECKOUT:-$HOME/Code/nix-config}"
FLAKE_REF="github:dappermint/nix-config"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }

log "apt: base system and the toolchains nix does not own here"
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  build-essential pkg-config \
  python3-pip python3-venv python3-dev \
  golang-go fish git curl wget ca-certificates xz-utils \
  man-db less bash-completion

if [ ! -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  log "lix: fresh install"
  # always the lix installer, never cppnix-then-upgrade: upgrade-lix.sh dies on
  # a man page collision between nix-manual and lix and leaves the default
  # profile with no nix in it, and it does not migrate the daemon to the
  # socket-activated instanced unit lix expects
  curl -sSf -L https://install.lix.systems/lix | sh -s -- install --no-confirm
else
  log "lix: already installed, skipping"
fi
# shellcheck disable=SC1091
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

log "nix.conf: ensuring settings"
# applied here rather than through an installer flag, so this keeps working if
# the installer's flags change
conf_changed=""
while IFS= read -r line; do
  [ -n "$line" ] || continue
  key=${line%% =*}
  if ! sudo grep -qE "^[[:space:]]*${key}[[:space:]]*=" /etc/nix/nix.conf 2>/dev/null; then
    echo "$line" | sudo tee -a /etc/nix/nix.conf >/dev/null
    conf_changed=1
    echo "  added: $line"
  fi
done <<'CONF'
experimental-features = nix-command flakes
trusted-users = root
auto-optimise-store = true
warn-dirty = false
extra-substituters = https://cache.lix.systems
extra-trusted-public-keys = cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o=
CONF
[ -n "$conf_changed" ] && sudo systemctl restart nix-daemon.socket

if [ ! -d "$CHECKOUT/.git" ]; then
  log "checkout: cloning $FLAKE_REF into $CHECKOUT"
  mkdir -p "$(dirname "$CHECKOUT")"
  gh repo clone dappermint/nix-config "$CHECKOUT"
else
  log "checkout: already at $CHECKOUT"
fi

log "home-manager: activating rubicon"
# the repo is private, so the fetch needs a token; gh's lives in $HOME and
# survives a re-provision
if token=$(gh auth token 2>/dev/null) && [ -n "$token" ]; then
  export NIX_CONFIG="access-tokens = github.com=$token"
fi
# built straight from the flake's own pinned home-manager rather than whatever
# `nix run home-manager` resolves to today
nix build --no-link --print-out-paths "$CHECKOUT#homeConfigurations.rubicon.activationPackage" \
  | tail -1 \
  | xargs -I{} {}/activate

if [ ! -x "$HOME/.cargo/bin/rustup" ]; then
  log "rust: installing via rustup"
  # rustup owns its own toolchain updates, so it stays outside nix
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --profile default
else
  log "rust: already installed, skipping"
fi

log "shell: making fish the login shell"
# debian's /usr/bin/fish, not the nix one: it is a stable path already in
# /etc/shells, and it reads the same home-manager config either way
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/fish" ]; then
  grep -q '^/usr/bin/fish$' /etc/shells || echo /usr/bin/fish | sudo tee -a /etc/shells >/dev/null
  sudo chsh -s /usr/bin/fish "$USER"
  echo "login shell set to fish; it takes effect in a new terminal tab"
else
  echo "already fish"
fi

log "done. close this tab and open a new one."
