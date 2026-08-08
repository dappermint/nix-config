{ config, ... }:

let
  repo = import ../lib/repo.nix;

  nixpkgsBranch = "nixpkgs-unstable";
  nixpkgsMirror = "${config.home.homeDirectory}/Code/nixpkgs";

  # unauthenticated github api is 60 requests an hour, which a full input bump
  # blows through and then falls back to cached revisions. nix has no
  # access-tokens-file (NixOS/nix#6536), and writing a PAT into nix.conf puts it
  # on disk in cleartext, so borrow gh's token for the length of one command
  ghToken = ''
    set -l token (gh auth token 2>/dev/null)
    test -n "$token"; and set -lx NIX_CONFIG "access-tokens = github.com=$token"
  '';
in
{
  programs.nh = {
    enable = true;
    darwinFlake = repo.flake;
  };

  programs.fish = {
    shellAbbrs = {
      nixb = "nom build";
      nixd = "nom develop";
      nixs = "nom shell";
    };

    functions = {
      nix-mirror-setup = ''
        set -l mirror "${nixpkgsMirror}"
        if test -d $mirror/.git
          echo "mirror already exists at $mirror"
          return 0
        end
        mkdir -p (dirname $mirror)
        echo "cloning nixpkgs (partial, blob:none) into $mirror ..."
        git clone --filter=blob:none --no-checkout \
          --branch ${nixpkgsBranch} \
          https://github.com/NixOS/nixpkgs $mirror
        git -C $mirror update-ref refs/heads/${nixpkgsBranch} origin/${nixpkgsBranch}
        echo "done. local ref refs/heads/${nixpkgsBranch} points at upstream tip"
      '';

      nix-mirror-update = ''
        set -l mirror "${nixpkgsMirror}"
        if not test -d $mirror/.git
          echo "mirror missing; run nix-mirror-setup first" >&2
          return 1
        end
        echo "fetching origin/${nixpkgsBranch} (partial) ..."
        git -C $mirror fetch --filter=blob:none origin ${nixpkgsBranch}
        git -C $mirror update-ref refs/heads/${nixpkgsBranch} origin/${nixpkgsBranch}
        echo "updating flake input nixpkgs ..."
        ${ghToken}
        nix flake update nixpkgs --flake ${repo.directory}
      '';

      # the system builds from the remote now, so applying a change is
      # commit -> push -> nix-switch. the flake ref is passed explicitly rather
      # than left to NH_DARWIN_FLAKE, which any shell descended from a
      # pre-switch session never sees
      nix-switch = ''
        ${ghToken}
        nh darwin switch --diff always ${repo.flake}
      '';

      # only bumps the lock, and only against the checkout: nix cannot write a
      # lock into a remote flake. switching is a separate, deliberate step
      nix-update = ''
        ${ghToken}
        nix flake update --flake ${repo.directory}
        echo
        echo "lock bumped in ${repo.directory}. commit and push, then nix-switch"
      '';
    };
  };
}
