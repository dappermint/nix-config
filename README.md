# nix-config

nix system flake managing personal machines across darwin, nixos, and home-manager. built on lix, sops-nix, and nh.

## fleet

| node | role | platform | configuration |
| --- | --- | --- | --- |
| `apollo` | workstation | `aarch64-darwin` | `darwinConfigurations.apollo` |
| `gotham` | edge iot / sbc | `aarch64-linux` | `nixosConfigurations.gotham` |
| `rubicon` | mobile terminal | `aarch64-linux` | `homeConfigurations.rubicon` |

- `apollo`: primary apple silicon macbook running nix-darwin, omniwm, and personal dev toolchains.
- `gotham`: headless rk3328 rockchip sbc running nixos, home assistant, esphome, soft-serve, and telemetry.
- `rubicon`: avf linux guest on phone running standalone home-manager with fish, tmux, and neovim.

## workflow

systems build from remote `github:dappermint/nix-config`. applying changes:

```fish
git commit -am "feat: ..."
git push
nix-switch
```

to test local uncommitted changes without pushing:

```fish
nh darwin switch --diff always /etc/nix-darwin
```

## private inputs & public builds

`abode`, `waves` and `claude-config` are private inputs. for unauthenticated clones and fork pull requests, swap them for the in-repo stub:

```fish
set stub --override-input abode ./flakes/stub --override-input waves ./flakes/stub --override-input claude-config ./flakes/stub
nix flake check $stub
nix eval $stub .#darwinConfigurations.apollo.system.drvPath
```

ci runs on hosted runners and verifies the stubbed tree on every pull request without requiring access tokens.

## secrets

secrets are encrypted with sops (`secrets/secrets.yaml` and `secrets/gotham.yaml`) to host-specific age recipients.

```fish
sops secrets/secrets.yaml       # edit
sops -d secrets/secrets.yaml    # read
```

## checks

```fish
nix flake check                 # lint, eval, and smoke tests
nix fmt -- --ci                 # treefmt check
```
