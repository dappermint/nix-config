# nix-config

nix-darwin + home-manager for `meatwizard`, an aarch64 mac, and standalone
home-manager for `droid`, the android linux terminal guest on the phone. lix is
the nix implementation on both, sops-nix holds the secrets, homebrew owns the
casks and the handful of formulae nix cannot build cleanly.

## switching

the system builds from `github:dappermint/nix-config`, not from the checkout, so
`system.configurationRevision` is a real commit and never a dirty tree. applying
a change is three steps:

```fish
git commit -am "..."            # in /etc/nix-darwin
git push
nix-switch                      # nh darwin switch --diff always github:dappermint/nix-config
```

`nix-update` bumps `flake.lock` **in the checkout only** and then stops, because
nix cannot write a lock into a remote flake. commit and push the bump, then
`nix-switch`.

the repo is private, so every fetch needs a github token. both helpers borrow
one from `gh auth token` for the length of the command.

`nix-switch` also passes `--refresh`, and that is not optional: `tarball-ttl` is
a week here, so without it nix resolves `github:dappermint/nix-config` from
cache and cheerfully builds a revision that is days behind while reporting
success. if you invoke nix directly, carry both:

```fish
sudo NIX_CONFIG="access-tokens = github.com=$(gh auth token)" \
  darwin-rebuild switch --refresh --flake github:dappermint/nix-config#meatwizard
```

sudo has to come first: its env_reset strips a `NIX_CONFIG` exported in front of
it, but passes one given as an argument through to the command.

to test an uncommitted change without pushing, point at the checkout explicitly:

```fish
nh darwin switch --diff always /etc/nix-darwin
```

`nix-mirror-update` refreshes the local partial nixpkgs clone in `~/Code/nixpkgs`
first, then bumps only the `nixpkgs` input. `nix-mirror-setup` creates that clone.

a bare `nh darwin switch` is a trap: `NH_DARWIN_FLAKE` points at the github ref
but only shells started after a switch see it, nh's own fallback is the local
checkout, and neither path carries `--refresh`. use `nix-switch`, which does
both. `flake:nixpkgs` is pinned to the locked input, so `nix run nixpkgs#x` and
`nix shell nixpkgs#x` resolve to the same package set the system was built from
instead of fetching a second nixpkgs. `,` (comma) runs a package without
installing it, backed by the prebuilt `nix-index` database.

`docs/nix-review-2026-08.md` records the last upstream review: what changed,
what was left alone and why, and what to watch on the next lix release.

## layout

```
flake.nix                       inputs, the mkHost router, checks, devshell
hosts/meatwizard.nix            machine facts: hostname, platform, wifi allowlist, /etc/hosts pin
hosts/droid.nix                 the phone: username, home directory, its slice of lib/packages.nix
hosts/*-bootstrap.sh            blank machine to first activation, per platform
modules/                        generic system modules, none of them name the machine
home/dappy.nix                  imports only, one file per topic beside it
home/droid.nix                  the same, for the portable half of those topics
overlays/                       exposes packages/ under pkgs
packages/                       our own derivations
lib/                            shared constants, package groups and shell snippets
secrets/secrets.yaml            sops-encrypted
docs/                           point-in-time reviews, one file per pass
```

modules read `config.system.primaryUser` and `users.users.<user>.home`; home
modules read `config.home.homeDirectory`. no `primaryUsername` specialArg to
thread around.

## a new mac

`hosts/darwin-bootstrap.sh` takes a blank mac to its first switch: the handful
of defaults worth having before nix, rosetta, homebrew, lix, `~/.ssh/id_ed25519`
registered on github for auth and signing, the checkout at `/etc/nix-darwin`,
the sops age identity, and the first activation. the repo is private, so copy
the script over by airdrop or usb:

```sh
HOST=meatwizard bash darwin-bootstrap.sh
```

a fresh key is not a sops recipient, so the script prints the user and host age
keys and waits: add them to `.sops.yaml` from a mac that already decrypts, run
`sops updatekeys secrets/*.yaml`, push, then press enter. restoring the old
`~/.ssh/id_ed25519` before running skips that step. idempotent, re-run after
fixing whatever stopped it.

## droid

`droid` is the phone: the android linux terminal guest (avf debian 13 trixie,
aarch64). it is standalone home-manager rather than nixos, because the terminal
app owns the guest rootfs and re-provisions it from a cloud-init seed and a
rootfs backup. anything outside `/home/droid` is reverted when it does — that
took out a `chsh` once — so the checkout lives at `~/Code/nix-config` and not in
`/etc`. there is no ssh fallback either: cloud-init purges openssh-server on
every provision, so a broken login shell is only recoverable by reinstalling the
guest.

lix goes on with its own installer. upgrading a cppnix install in place is not
worth it: `upgrade-lix.sh` uninstalls cppnix, then fails to rebuild the profile
on a man page collision between `nix-manual` and `lix`, and leaves the profile
with no `nix` in it at all. it also leaves the daemon on the old single-service
layout, where lix wants `nix-daemon.socket` with `Accept=yes` dispatching to an
instanced `nix-daemon@.service`.

`hosts/droid-bootstrap.sh` replays the whole guest from nothing — apt, lix,
nix.conf, the checkout, the home-manager activation, rustup and the login shell
— and is idempotent:

```fish
bash ~/Code/nix-config/hosts/droid-bootstrap.sh
```

switching is the same commit -> push -> `nix-switch` as meatwizard;
`home/nix-tools.nix` picks the home-manager path on linux and the nh path on
darwin, so the muscle memory is the same on both.

droid imports the portable half of the home modules: fish, git, neovim,
nix-tools, ssh, starship, tmux and uv. aws, clownops and kube are work
infrastructure the phone cannot reach, obs, fonts and zed are gui concerns, and
sops wants an age key this guest does not hold yet. tmux, starship and neovim
are droid-only in the other direction: they exist because a phone terminal is
~50 columns with a soft keyboard and no window manager.

ci runs on a hosted `ubuntu-24.04-arm` runner, so it lints the tree and
evaluates droid and mkspi natively through `checks.aarch64-linux.*`. nothing
aarch64-linux is built in ci; it only has to evaluate.

## checks

```fish
nix flake check                 # lint + eval + smoke
direnv allow                    # loads the devshell on cd, one time only
nix develop                     # same shell without direnv
pre-commit install              # installs both the pre-commit and commit-msg hooks
```

the devshell carries sops, nixfmt, statix, deadnix, nh, ssh-to-age and
pre-commit. the lint hooks only resolve inside it, so commit from the repo with
direnv active or wrap the commit in `nix develop -c`.

- `lint` runs nixfmt, deadnix and statix over the tree
- `eval` forces the whole configuration through evaluation without building it
- `smoke` builds `darwinConfigurations.meatwizard.system` and asserts that
  `local-maintenance`, `maintenance-status`, `nix-cache-push` and `grok` are on
  it, and that the generated brewfile still declares awscli

`.pre-commit-config.yaml` mirrors `lint` locally and enforces conventional
commits on the commit message. ci lints and evaluates all three hosts on every
push from a hosted linux runner, and a weekly job on hosted macos opens a
`flake.lock` bump pr only if `nix flake check`, which builds the darwin
closure, passes on the bumped tree. both need a `NIX_ACCESS_TOKEN` repo secret
that can read the private `abode` input.

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
zstd-12 and then `aws s3 sync`ed, throttled to 2MB/s by the `nix-cache-writer`
profile. it was zstd-19, which pinned five cores for minutes every run and was
worth a few percent of size; `services.nix-cache-push.compressionLevel` raises it
again if you ever want that back.

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
