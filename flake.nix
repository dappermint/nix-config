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
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    ratatouille.url = "github:dappermint/ratatouille";
    ratatouille.inputs.nixpkgs.follows = "nixpkgs";
    tart.url = "github:dappermint/tart";
    tart.inputs.nixpkgs.follows = "nixpkgs";
    abode.url = "github:dappermint/abode";
    abode.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      ...
    }:
    let
      system = "aarch64-darwin";
      linuxSystem = "aarch64-linux";

      # the system's own package set, so allowUnfree and the overlay list stay
      # declared once in modules/system.nix
      pkgs = self.darwinConfigurations.meatwizard.pkgs;

      mkHost =
        hostModule:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit self inputs; };
          modules = [ hostModule ];
        };

      meatwizard = self.darwinConfigurations.meatwizard.system;

      # droid is a standalone home-manager host, so it has no system to borrow
      # a package set from the way meatwizard does. same overlay and unfree
      # policy as modules/system.nix, so a package resolves to the same thing
      # on both hosts
      linuxPkgs = import inputs.nixpkgs {
        system = linuxSystem;
        config.allowUnfree = true;
        overlays = [ (import ./overlays) ];
      };

      droid = self.homeConfigurations.droid.activationPackage;

      mkspi = self.nixosConfigurations.mkspi.config.system.build.toplevel;

      # per system so the hosted linux ci can run it without a mac
      lint =
        p:
        p.runCommand "lint"
          {
            nativeBuildInputs = [
              p.deadnix
              p.nixfmt
              p.statix
            ];
          }
          ''
            cd ${self}
            find . -name '*.nix' -print0 | xargs -0 nixfmt --check
            deadnix --fail .
            statix check .
            touch $out
          '';
    in
    {
      darwinConfigurations.meatwizard = mkHost ./hosts/meatwizard.nix;

      nixosConfigurations.mkspi = inputs.nixpkgs.lib.nixosSystem {
        specialArgs = { inherit self inputs; };
        modules = [ ./hosts/mkspi.nix ];
      };

      homeConfigurations.droid = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = linuxPkgs;
        extraSpecialArgs = { inherit self inputs; };
        modules = [ ./hosts/droid.nix ];
      };

      formatter.${system} = pkgs.nixfmt-tree;
      formatter.${linuxSystem} = linuxPkgs.nixfmt-tree;

      packages.${system} = {
        default = meatwizard;
        inherit (pkgs) google-sans-flex;
      };

      packages.${linuxSystem} = {
        default = droid;
        inherit mkspi;
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

      checks.${linuxSystem} = {
        lint = lint linuxPkgs;

        eval =
          linuxPkgs.runCommand "eval-droid"
            {
              drv = builtins.unsafeDiscardStringContext droid.drvPath;
            }
            ''
              test -n "$drv"
              touch $out
            '';

        eval-mkspi =
          linuxPkgs.runCommand "eval-mkspi"
            {
              drv = builtins.unsafeDiscardStringContext mkspi.drvPath;
            }
            ''
              test -n "$drv"
              touch $out
            '';
      };

      checks.${system} = {
        lint = lint pkgs;

        eval =
          pkgs.runCommand "eval-meatwizard"
            {
              drv = builtins.unsafeDiscardStringContext meatwizard.drvPath;
            }
            ''
              test -n "$drv"
              touch $out
            '';

        smoke =
          pkgs.runCommand "smoke-meatwizard"
            {
              brewfile = self.darwinConfigurations.meatwizard.config.homebrew.brewfile;
            }
            ''
              system=${meatwizard}

              test -x "$system/activate"

              for bin in local-maintenance maintenance-status nix-cache-push; do
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
