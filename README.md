# nix-config

nix-darwin + home-manager for `meatwizard`, an aarch64 mac. lix is the nix
implementation, sops-nix holds the secrets, homebrew owns the casks and the
handful of formulae nix cannot build cleanly.

## switching

```fish
nix-update                      # nh darwin switch --update --diff always /etc/nix-darwin
```

without the helper:

```fish
sudo darwin-rebuild switch --flake /etc/nix-darwin#meatwizard
```

`nix-mirror-update` refreshes the local partial nixpkgs clone in `~/Code/nixpkgs`
first, then bumps only the `nixpkgs` input. `nix-mirror-setup` creates that clone.

`nh darwin switch` needs no path: home-manager sets `NH_DARWIN_FLAKE`, and nh
falls back to `/etc/nix-darwin` on its own regardless, which is where this repo
lives. `flake:nixpkgs` is pinned to the locked input, so `nix run nixpkgs#x` and
`nix shell nixpkgs#x` resolve to the same package set the system was built from
instead of fetching a second nixpkgs. `,` (comma) runs a package without
installing it, backed by the prebuilt `nix-index` database.

`docs/nix-review-2026-08.md` records the last upstream review: what changed,
what was left alone and why, and what to watch on the next lix release.

## layout

```
flake.nix                       inputs, the mkHost router, checks, devshell
hosts/meatwizard.nix            machine facts: hostname, platform, wifi allowlist, /etc/hosts pin
modules/                        generic system modules, none of them name the machine
home/dappy.nix                  imports only, one file per topic beside it
overlays/                       exposes packages/ under pkgs
packages/                       our own derivations
lib/                            shared constants and shell snippets
secrets/secrets.yaml            sops-encrypted
docs/                           point-in-time reviews, one file per pass
```

modules read `config.system.primaryUser` and `users.users.<user>.home`; home
modules read `config.home.homeDirectory`. no `primaryUsername` specialArg to
thread around.

## checks

```fish
nix flake check                 # lint + eval + smoke
nix develop                     # sops, nixfmt, statix, deadnix, nh, ssh-to-age, pre-commit
pre-commit install              # installs both the pre-commit and commit-msg hooks
```

- `lint` runs nixfmt, deadnix and statix over the tree
- `eval` forces the whole configuration through evaluation without building it
- `smoke` builds `darwinConfigurations.meatwizard.system` and asserts that
  `local-maintenance`, `nix-cache-push` and `grok` are on it, and that the
  generated brewfile still declares awscli

`.pre-commit-config.yaml` mirrors `lint` locally and enforces conventional
commits on the commit message. ci runs lint and eval on every push, builds the
system in a second job, and opens a weekly `flake.lock` bump pr only if
`nix flake check` passes on the bumped tree.

## secrets

everything encrypted lives in `secrets/secrets.yaml`. `.sops.yaml` encrypts to
two age recipients:

- `meatwizard` — derived from `~/.ssh/id_ed25519`
- `meatwizard_host` — derived from `/etc/ssh/ssh_host_ed25519_key`

either one alone can decrypt. sops-nix uses the ssh keys directly at
activation; the sops cli uses the age identity at
`~/.config/sops/age/keys.txt`, pointed at by `SOPS_AGE_KEY_FILE` because sops
on darwin otherwise looks in `~/Library/Application Support`.

```fish
sops secrets/secrets.yaml       # edit
sops -d secrets/secrets.yaml    # read
```

what is in there and where it lands:

| key | rendered to |
| --- | --- |
| `nix_cache_priv_key` | `/run/secrets/...`, referenced by `nix.settings.secret-key-files` |
| `conway_kubeconfig` | `~/.kube/conway`, merged into `KUBECONFIG` |
| `youtube_stream_key` | `~/.config/obs/youtube-stream-key` |
| `upcloud_token`, `clownway_*_host` | `secrets.fish`, sourced by fish at startup |
| `aws_sso_*` | `~/.aws/config` |
| `nix_cache_{reader,writer}_*` | `~/.aws/credentials` |

`~/.aws/config` and `~/.aws/credentials` are sops templates, so **do not hand
edit them** — they are overwritten on every activation. tofu is still the source
of truth for the s3 cache keys; `nix-cache-creds-import` copies its outputs into
sops, then a switch re-renders the file.

the clownupdate ssh targets and the aws account identifiers are secrets so they
never appear in a nix expression. the `ha.int.sandb0x.space` pin in
`hosts/meatwizard.nix` is the exception: `/etc/hosts` is baked at eval time and
cannot read a runtime secret.

### if the age key is lost

as long as one of the two recipients survives you are fine. re-derive the user
identity from the ssh key:

```fish
nix run nixpkgs#ssh-to-age -- -private-key -i ~/.ssh/id_ed25519 -o ~/.config/sops/age/keys.txt
```

if the machine is being rebuilt, decrypt with the surviving key first, then add
the new recipient to `.sops.yaml` and run `sops updatekeys secrets/secrets.yaml`.

if **both** keys are gone the file is unrecoverable and each secret has to be
reissued: generate a new cache signing key and update
`nix.settings.trusted-public-keys`, reissue the upcloud token, re-fetch the
conway kubeconfig, re-copy the youtube stream key, `tofu apply` for the s3
credentials, and retype the inventory.

## launchd

| job | cadence | what it does |
| --- | --- | --- |
| `org.dappy.local-maintenance` | 10:00 daily + at load | prunes uv (7d), npm (30d) and brew (30d) caches; under 15% free writes a dust report and notifies; under 10% clears the go build cache and an oversized cache staging dir; under 5% clears the go module cache |
| `org.dappy.nix-cache-push` | every 3h | pushes the current system closure to s3 |
| `org.nixos.nix-pressure-gc` | every 6h | `nix-collect-garbage --delete-older-than 7d`, but only under 10% free |

nix's own gc also runs weekly on sunday at 04:00. `local-maintenance --status`
(or `maintenance-status`) prints the last run of each task and current free
space. logs are under `~/Library/Logs/`.

## how cache push decides to run

`nix-cache-push` bails out early, quietly, unless all of these hold:

1. the closure is not the one already recorded in `~/.local/state/nix-cache-push/last-system`
2. there is a default route, and its interface matches `en*` or `bridge*`
3. if that interface is on wi-fi, the ssid is in `services.nix-cache-push.safeSSIDs`
4. no other cache operation holds the lock

`--force` skips 1 through 3. paths given as arguments override the default of
`/run/current-system`. the closure is staged to `~/.cache/nix-cache-staging` with
zstd-19 and then `aws s3 sync`ed, throttled to 2MB/s by the `nix-cache-writer`
profile.

## homebrew and netbird

homebrew runs with `cleanup = "uninstall"` and `--force-cleanup`, which deletes
netbird's LaunchDaemon on every version bump. nix-darwin cannot own that plist
without fighting the formula, so activation repairs it: reinstall the plist if
it vanished, bootstrap it if launchd forgot it, and restart the service only
when the binary hash actually changed.

## bumping grok

```fish
./packages/grok/update.sh           # latest stable from xai's version pointer
./packages/grok/update.sh 0.2.120   # a specific version
```

it rewrites the version and both platform hashes in
`packages/grok/default.nix`.
