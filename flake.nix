{
  description = "meatwizard nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    mac-cleaner.url = "github:dappermint/mac-cleaner";
    mac-cleaner.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      ...
    }:
    let
      system = "aarch64-darwin";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ (import ./overlays) ];
      };

      mkHost =
        hostModule:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit self inputs; };
          modules = [ hostModule ];
        };

      meatwizard = self.darwinConfigurations.meatwizard.system;
    in
    {
      darwinConfigurations.meatwizard = mkHost ./hosts/meatwizard.nix;

      formatter.${system} = pkgs.nixfmt;

      packages.${system} = {
        default = meatwizard;
        inherit (pkgs) geist-mono-nerd-font grok;
      };

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          deadnix
          nh
          nixfmt
          pre-commit
          sops
          ssh-to-age
          statix
        ];

        shellHook = ''
          export SOPS_AGE_KEY_FILE="''${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
        '';
      };

      checks.${system} = {
        lint =
          pkgs.runCommand "lint"
            {
              nativeBuildInputs = [
                pkgs.deadnix
                pkgs.nixfmt
                pkgs.statix
              ];
            }
            ''
              cd ${self}
              find . -name '*.nix' -print0 | xargs -0 nixfmt --check
              deadnix --fail .
              statix check .
              touch $out
            '';

        # forces the whole configuration through evaluation without building it,
        # which is the cheap gate ci can run on every push
        eval =
          pkgs.runCommand "eval-meatwizard"
            {
              drv = builtins.unsafeDiscardStringContext meatwizard.drvPath;
            }
            ''
              test -n "$drv"
              touch $out
            '';

        # the expensive gate: builds the system closure and asserts the tools we
        # actually depend on landed on it. aws is homebrew-owned, so the closest
        # honest assertion is that the generated Brewfile still declares it
        smoke =
          pkgs.runCommand "smoke-meatwizard"
            {
              brewfile = self.darwinConfigurations.meatwizard.config.homebrew.brewfile;
            }
            ''
              system=${meatwizard}

              test -x "$system/activate"

              for bin in local-maintenance maintenance-status nix-cache-push grok; do
                test -x "$system/sw/bin/$bin" || {
                  echo "missing $bin on the built system" >&2
                  exit 1
                }
              done

              grep -q -- '--status' "$system/sw/bin/local-maintenance"
              printf '%s' "$brewfile" | grep -q 'awscli'

              touch $out
            '';
      };
    };
}
