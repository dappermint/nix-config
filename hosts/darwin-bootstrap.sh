#!/usr/bin/env bash
# take a blank mac to the point where nix-darwin owns it: rosetta, homebrew,
# lix, an ssh key registered with github, the checkout, sops access and the
# first switch.
#
#   bash darwin-bootstrap.sh            # HOST=<name> for anything but meatwizard
#
# the repo is private, so on a blank mac this file arrives by airdrop or usb.
# idempotent: safe to re-run after fixing whatever stopped it.
set -euo pipefail

HOST="${HOST:-meatwizard}"
CHECKOUT=/etc/nix-darwin
REPO=dappermint/nix-config
KEY="$HOME/.ssh/id_ed25519"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }

[ "$(uname -m)" = arm64 ] || { echo "aarch64-darwin only" >&2; exit 1; }

# the first build runs for a while, don't let idle sleep kill it
caffeinate -dimsu -w $$ &

#-----------------------------------------------------------------------------
log "defaults: the ones worth having before nix-darwin takes over"
# same values as modules/defaults.nix, so the switch is a no-op for these.
# key repeat and trackpad only apply after a logout
defaults write -g AppleInterfaceStyle Dark
defaults write -g AppleShowAllExtensions -bool true
defaults write -g ApplePressAndHoldEnabled -bool false
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15
defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false
defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write -g NSAutomaticDashSubstitutionEnabled -bool false
defaults write -g com.apple.swipescrolldirection -bool true
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder FXPreferredViewStyle clmv
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
killall Dock Finder 2>/dev/null || true
# caps lock -> control, live immediately
hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":30064771129,"HIDKeyboardModifierMappingDst":30064771296}]}' >/dev/null

#-----------------------------------------------------------------------------
if [ ! -e /Library/Apple/usr/libexec/oah/libRosettaRuntime ]; then
  log "rosetta: installing"
  softwareupdate --install-rosetta --agree-to-license
fi

#-----------------------------------------------------------------------------
if [ ! -x /opt/homebrew/bin/brew ]; then
  log "homebrew: fresh install (brings the command line tools and git)"
  # NONINTERACTIVE skips the prompt but still needs sudo cached up front
  sudo -v
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  log "homebrew: already installed, skipping"
fi

#-----------------------------------------------------------------------------
if [ ! -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  log "lix: fresh install"
  curl -sSf -L https://install.lix.systems/lix | sh -s -- install --no-confirm
else
  log "lix: already installed, skipping"
fi
# shellcheck disable=SC1091
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
export NIX_CONFIG="experimental-features = nix-command flakes"

tool() { echo "$(nix build --no-link --print-out-paths "nixpkgs#$1")/bin/$1"; }
GH=$(tool gh)
S2A=$(tool ssh-to-age)

#-----------------------------------------------------------------------------
if [ ! -f "$KEY" ]; then
  log "ssh: generating $KEY"
  # no passphrase: sops-nix derives its age identity from this key during
  # activation and has no way to prompt for one
  install -d -m 700 "$HOME/.ssh"
  ssh-keygen -q -t ed25519 -C "$USER@$HOST" -f "$KEY" -N ""
else
  log "ssh: $KEY exists, keeping it"
fi
# macos only creates host keys when remote login is first enabled, and the
# host key is the second sops recipient
sudo ssh-keygen -A >/dev/null

mkdir -p "$HOME/.config/sops/age"
if [ ! -s "$HOME/.config/sops/age/keys.txt" ]; then
  (umask 077 && "$S2A" -private-key -i "$KEY" > "$HOME/.config/sops/age/keys.txt")
fi

#-----------------------------------------------------------------------------
log "github: auth and key registration"
scopes=admin:public_key,admin:ssh_signing_key
if ! "$GH" auth status -h github.com >/dev/null 2>&1; then
  "$GH" auth login -h github.com -p ssh --skip-ssh-key -w -s "$scopes"
elif ! "$GH" auth status -h github.com 2>&1 | grep -q admin:ssh_signing_key; then
  "$GH" auth refresh -h github.com -s "$scopes"
fi
pub=$(cut -d' ' -f1,2 "$KEY.pub")
# git signs commits with this same key (home/git.nix), so it goes up twice
"$GH" api user/keys --jq '.[].key' | grep -qxF "$pub" \
  || "$GH" ssh-key add "$KEY.pub" --type authentication --title "$HOST"
"$GH" api user/ssh_signing_keys --jq '.[].key' | grep -qxF "$pub" \
  || "$GH" ssh-key add "$KEY.pub" --type signing --title "$HOST"

#-----------------------------------------------------------------------------
export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new"
if [ ! -d "$CHECKOUT/.git" ]; then
  log "checkout: cloning $REPO into $CHECKOUT"
  sudo install -d -o "$USER" -g staff "$CHECKOUT"
  git clone "git@github.com:$REPO.git" "$CHECKOUT"
else
  log "checkout: already at $CHECKOUT"
fi

#-----------------------------------------------------------------------------
log "sops: checking this mac can decrypt"
user_age=$("$S2A" < "$KEY.pub")
host_age=$("$S2A" < /etc/ssh/ssh_host_ed25519_key.pub)
until grep -qE "$user_age|$host_age" "$CHECKOUT/.sops.yaml"; do
  cat <<EOF
not a sops recipient yet, activation would fail on every secret. from a mac
that is one, put these in .sops.yaml, then run
'sops updatekeys secrets/*.yaml' and commit + push:

  user  $user_age
  host  $host_age

EOF
  read -rp "enter once pushed "
  git -C "$CHECKOUT" pull --ff-only
done

#-----------------------------------------------------------------------------
log "nix-darwin: building $HOST"
# private flake inputs (abode) need a token; borrowed for this process only
NIX_CONFIG="$NIX_CONFIG
access-tokens = github.com=$("$GH" auth token)"
sys=$(nix build --no-link --print-out-paths "$CHECKOUT#darwinConfigurations.$HOST.system")

# the lix installer edits /etc/zshrc and /etc/bashrc and writes nix.conf;
# activation refuses to overwrite anything it does not recognise
( cd "$sys/etc" && find . -type l ) | while read -r f; do
  f="/etc/${f#./}"
  if [ -e "$f" ] && [ ! -L "$f" ]; then
    sudo mv "$f" "$f.before-nix-darwin"
  fi
done
if [ -e /etc/nix/nix.custom.conf ]; then
  sudo mv /etc/nix/nix.custom.conf /etc/nix/nix.custom.conf.before-nix-darwin
fi

log "nix-darwin: activating"
# what darwin-rebuild switch does, minus a second eval as root, which would
# need the token again
sudo /nix/var/nix/profiles/default/bin/nix-env -p /nix/var/nix/profiles/system --set "$sys"
sudo "$sys/activate"

#-----------------------------------------------------------------------------
fish=/run/current-system/sw/bin/fish
if [ "$(dscl . -read "/Users/$USER" UserShell | awk '{print $2}')" != "$fish" ]; then
  log "shell: making fish the login shell"
  grep -qx "$fish" /etc/shells || echo "$fish" | sudo tee -a /etc/shells >/dev/null
  sudo chsh -s "$fish" "$USER"
fi

log "done. log out and back in, from here on it's nix-switch"
