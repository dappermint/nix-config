homebrew := "modules/homebrew.nix"

# insert a brew or cask into modules/homebrew.nix, sorted by bare name
add kind name file=homebrew:
    #!/usr/bin/env python3
    import re, sys
    kind, name, path = "{{ kind }}", "{{ name }}", "{{ file }}"
    if kind not in ("brews", "casks") or not re.fullmatch(r"[\w.@+-]+(/[\w.-]+/[\w.@+-]+)?", name):
        sys.exit("usage: just add brews|casks [tap/]name")
    text = open(path).read()
    lines = text.split("\n")
    start = lines.index("    " + kind + " = [")
    end = lines.index("    ];", start)
    entries = []
    for i in range(start + 1, end):
        m = re.fullmatch(r'      "(.+)"', lines[i])
        if m:
            entries.append((i, m.group(1)))
    if name in [n for _, n in entries]:
        sys.exit(name + " already in " + kind)
    tap = name.rsplit("/", 1)[0]
    if "/" in name and 'name = "' + tap + '";' not in text:
        sys.exit("tap " + tap + " missing from taps")
    key = lambda n: n.rsplit("/", 1)[-1].lower()
    # after the last smaller entry, so the next entry's comment stays attached to it
    at = max([i for i, n in entries if key(n) < key(name)], default=start) + 1
    lines.insert(at, '      "' + name + '"')
    open(path, "w").write("\n".join(lines))
    print("added " + name + " to " + kind)

# prune stale build artifacts across dev repos and system caches
clean:
    @echo "==> pruning stale swift .build and derived data..."
    @find /Volumes/onyx -maxdepth 5 -type d -name ".build" -mtime +14 -prune -exec rm -rf {} + 2>/dev/null || true
    @rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null || true
    @echo "==> pruning uv, go, and brew caches..."
    @which uv >/dev/null 2>&1 && uv cache prune 2>/dev/null || true
    @which go >/dev/null 2>&1 && go clean -cache 2>/dev/null || true
    @which brew >/dev/null 2>&1 && brew cleanup --prune=all 2>/dev/null || true
    @echo "==> checking local-maintenance status..."
    @which local-maintenance >/dev/null 2>&1 && local-maintenance --status || true
