#!/usr/bin/env bash
# bump the pinned grok version and both artifact hashes.
#
#   ./packages/grok/update.sh           # latest stable
#   ./packages/grok/update.sh 0.2.120   # a specific version
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
nix_file="$here/default.nix"

base=https://storage.googleapis.com/grok-build-public-artifacts/cli
channel=${GROK_CHANNEL:-stable}

version=${1:-}
if [ -z "$version" ]; then
  version=$(curl -fsSL "$base/$channel" | tr -d '[:space:]')
fi

if ! printf '%s' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9._]+)?$'; then
  echo "unexpected version string: $version" >&2
  exit 1
fi

current=$(sed -n 's/^  version = "\(.*\)";$/\1/p' "$nix_file")
if [ "$version" = "$current" ]; then
  echo "grok is already pinned at $version"
  exit 0
fi

echo "grok $current -> $version"

to_sri() {
  nix hash to-sri --type sha256 "$1" 2>/dev/null \
    || nix hash convert --hash-algo sha256 --to sri "$1"
}

for pair in aarch64-darwin:macos-aarch64 x86_64-darwin:macos-x86_64; do
  platform=${pair##*:}
  echo "  prefetching $platform"
  raw=$(nix-prefetch-url --type sha256 "$base/grok-$version-$platform" 2>/dev/null)
  sri=$(to_sri "$raw")

  python3 - "$nix_file" "$platform" "$sri" <<'PY'
import re
import sys

path, platform, sri = sys.argv[1:4]
source = open(path).read()
pattern = re.compile(r'(platform = "%s";\s*\n\s*hash = ")[^"]*(")' % re.escape(platform))
updated, count = pattern.subn(lambda m: m.group(1) + sri + m.group(2), source)
if count != 1:
    raise SystemExit("expected exactly one hash for %s, rewrote %d" % (platform, count))
open(path, "w").write(updated)
PY
done

python3 - "$nix_file" "$version" <<'PY'
import re
import sys

path, version = sys.argv[1:3]
source = open(path).read()
updated, count = re.subn(
    r'^  version = "[^"]*";$',
    '  version = "%s";' % version,
    source,
    flags=re.MULTILINE,
)
if count != 1:
    raise SystemExit("expected exactly one version line, rewrote %d" % count)
open(path, "w").write(updated)
PY

echo "done. build it with: nix build .#grok"
