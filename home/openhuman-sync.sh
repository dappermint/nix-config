#!/bin/sh
# openhuman refuses symlinks for AGENTS.md (O_NOFOLLOW) and skips symlinked skill dirs, so copy
set -eu

SRC="$HOME/.hermes/skills"
DST="$HOME/.openhuman/skills"
WS="$HOME/.openhuman/users/$(sed -n 's/^user_id = "\(.*\)"/\1/p' "$HOME/.openhuman/active_user.toml")/workspace"

SKILLS="
nix-darwin-ops
mikrotik-routeros
kubernetes-cluster-ops
honcho-selfhosted-conway
9router-headroom
home-assistant
home-assistant-protocols
sandbox-homeassistant
sbx-intelmac
sbx-internal-dns
sbx-network-infra
sbx-website
sbx-homelab-k3s
systematic-debugging
falsifiable-verification
dappy-voice
conway-node-onboarding
longhorn-volume-triage
cloudflare-tunnel-ingress
mkspi-homelab
"

mkdir -p "$DST"
for s in $SKILLS; do
  src=$(find "$SRC" -maxdepth 3 -type d -name "$s" | head -n 1)
  [ -n "$src" ] || { echo "missing: $s" >&2; continue; }
  rsync -a --delete "$src/" "$DST/$s/"
done

cp "$HOME/AGENTS.md" "$WS/AGENTS.md"
echo "synced $(ls "$DST" | wc -l | tr -d ' ') skills + AGENTS.md -> $WS"
