# mac-cleaner

category-first macos storage inventory and cleanup for a nix-managed developer machine

the default command opens a live scan ledger and then a full-screen tui ordered by macos storage category and size

the launch ledger names every check, shows which ones are queued or running, reports elapsed time and summarizes what each completed check surfaced. it also states the no-deletion boundary while the scan is running

the tui owns an alternate screen and renders complete frames by terminal row. it redraws only changed rows, reacts to terminal resize events during scans and navigation, and restores the original screen, cursor and terminal mode on exit

## root scope

```sh
sudo mac-cleaner --root
sudo mac-cleaner scan --root --deep --json
```

`--root` requires effective uid 0 and adds read-only inventory for System Data, macOS, and Other Users & Shared. it indexes large children under `/Library`, `/private/var`, `/Users`, `/nix/store`, `/opt/homebrew`, `/usr/local`, and the sealed `/System` tree

when launched through `sudo`, supported cleanup commands run as the invoking uid with that user's home and groups. root-owned inventory rows remain protected and cannot be selected

## category model

results sort by category first, allocated size second. categories follow the macos Storage vocabulary: Applications, Documents, Developer, iCloud Drive, iOS Files, media categories, Mail, Messages, Music Creation, Photos, Trash, Other Users & Shared, macOS, and System Data

this is a filesystem inventory, not Apple's private attribution engine. System Data is the fallback for caches, logs, vm state, app support, package stores, fonts, plug-ins and other data that does not resolve to a more specific category

## safety model

| label | meaning | behavior |
| --- | --- | --- |
| `safe` | the owning tool provides a supported cleanup command | selectable, never selected until you press `space` or `a` |
| `review` | rebuildable state or personal files that need a human look | selectable one item at a time |
| `destructive` | permanent deletion | requires the exact `empty trash` phrase |
| `protected` | games, app data, cloud data or application bundles | visibility only, never selectable |

path-based cleanup moves an item to `~/.Trash` with an unambiguous suffix instead of deleting it directly. this does not reclaim space until Trash is emptied, and the storage rail accounts for that distinction

the scanner sums allocated blocks, not apparent file lengths. sparse files therefore do not show up as fake cleanup wins

## supported cleanup

- homebrew leftovers via `brew cleanup --prune=all`, estimated first with `--dry-run`
- unused uv cache entries via `uv cache prune`
- npm cache garbage collection via `npm cache verify`
- go build and test cache via `go clean -cache -testcache`
- go module downloads via `go clean -modcache`, marked for review because they need network access to rebuild
- unreachable nix store paths via `nix store gc`, estimated first with `--dry-run`
- unused docker objects via `docker system prune --force`, without volumes or `--all`
- large per-app caches and downloads, moved to Trash
- project-local `node_modules`, rust `target`, `.direnv` and `.venv` directories in deep scans, only when their project marker is present

large data under Application Support, Containers, Group Containers and `/Applications` is shown as protected. the tool does not turn a steam library, whisky bottle, telegram account, icloud data or an app bundle into "clutter" just because it is large

## tui controls

```text
j/k or arrows  move
tab             next risk filter
space           mark item
a               mark safe set
enter           inspect
c               execute marked set
r               rescan
?               keymap
q               quit
```

## scriptable commands

```sh
mac-cleaner scan
mac-cleaner scan --deep --json
sudo mac-cleaner scan --root --deep --json
mac-cleaner plan --all-safe
mac-cleaner clean --all-safe --dry-run
mac-cleaner clean --yes --all-safe
mac-cleaner clean --yes --confirm 'empty trash' empty-trash
```

flags must come before item ids. no cleanup action uses a shell, item ids only resolve against the current scan, and arbitrary paths are not accepted

## research boundaries

- apple defines System Data as the catch-all for files outside more specific categories, primarily logs, caches, vm files, runtime resources, temporary files, fonts, app support and plug-ins. apple also marks System Data, macOS and Other Users as size-only categories rather than directly manageable lists: [change Storage settings on Mac](https://support.apple.com/guide/mac-help/mchl3d437fbc/mac)
- apple says moving a file to Trash does not make the space available until Trash is emptied. the tui reports "to Trash" separately from immediately reclaimable space: [free up storage space on mac](https://support.apple.com/en-us/102624)
- apple counts local Time Machine snapshots as available storage and removes them as space is needed. mac-cleaner deliberately leaves them alone: [about Time Machine local snapshots](https://support.apple.com/en-us/102154)
- nix garbage collection deletes paths that are unreachable from garbage-collector roots. current profiles and rollback generations remain roots, so the safe action does not delete generations: [nix-store garbage collection](https://nix.dev/manual/nix/2.34/command-ref/nix-store/gc)
- deleting old nix generations makes those rollbacks impossible. that policy remains in the existing pressure-aware maintenance module instead of being hidden inside this tui: [nix-collect-garbage](https://nix.dev/manual/nix/2.34/command-ref/nix-collect-garbage)
- homebrew documents both `cleanup --dry-run` and `--prune=all`: [brew manpage](https://docs.brew.sh/Manpage.html#cleanup-options-formulacask-)
- uv documents `cache prune` as safe to run periodically and warns against modifying its cache directly: [uv caching](https://docs.astral.sh/uv/concepts/cache/)
- npm describes `cache verify` as integrity verification plus garbage collection, while a full cache clean is normally unnecessary: [npm cache](https://docs.npmjs.com/cli/v7/commands/npm-cache/)
- go documents the build cache as rebuildable and `go clean -modcache` as removal of downloaded dependency source: [go clean](https://go.dev/cmd/go/#hdr-Remove_object_files_and_cached_files)
- cargo now garbage-collects its global cache automatically, so mac-cleaner only discovers project-local rust `target` directories: [cargo cache configuration](https://doc.rust-lang.org/cargo/reference/config.html#cache)
- docker documents that the default system prune excludes volumes and does not use `--all`: [docker system prune](https://docs.docker.com/reference/cli/docker/system/prune/)

root does not bypass Full Disk Access or SIP. skipped entries are counted in scan notes

## development

```sh
go test ./...
go run . scan --deep
nix build path:/etc/nix-darwin#mac-cleaner
```
