{ config, ... }:

let
  repo = import ../lib/repo.nix;

  nixpkgsBranch = "nixpkgs-unstable";
  nixpkgsMirror = "${config.home.homeDirectory}/Code/nixpkgs";
in
{
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
        nix flake update nixpkgs --flake ${repo.directory}
      '';

      nix-update = ''
        nh darwin switch --update --diff always ${repo.directory}
      '';
    };
  };
}
