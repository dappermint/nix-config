{
  description = "palantir fleet nix system flake";

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
    waves.url = "github:dappermint/waves";
    waves.inputs.nixpkgs.follows = "nixpkgs";
    pixeldish.url = "github:dappermint/pixeldish";
    pixeldish.inputs.nixpkgs.follows = "nixpkgs";
    claude-config = {
      url = "github:dappermint/claude-config";
      flake = false;
    };
    # no nixpkgs follows: lix asserts lowdown < 3.0.0, which unstable is past
    lix.url = "https://git.lix.systems/lix-project/lix/archive/2.96.0.tar.gz";
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
      pkgs = self.darwinConfigurations.apollo.pkgs;

      mkHost =
        hostModule:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit self inputs; };
          modules = [ hostModule ];
        };

      apollo = self.darwinConfigurations.apollo.system;

      # rubicon is a standalone home-manager host, so it has no system to borrow
      # a package set from the way apollo does. same overlay and unfree
      # policy as modules/system.nix, so a package resolves to the same thing
      # on both hosts
      linuxPkgs = import inputs.nixpkgs {
        system = linuxSystem;
        config.allowUnfree = true;
        overlays = [ (import ./overlays) ];
      };

      rubicon = self.homeConfigurations.rubicon.activationPackage;

      gotham = self.nixosConfigurations.gotham.config.system.build.toplevel;

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
      darwinConfigurations.apollo = mkHost ./hosts/apollo.nix;

      nixosConfigurations.gotham = inputs.nixpkgs.lib.nixosSystem {
        specialArgs = { inherit self inputs; };
        modules = [ ./hosts/gotham ];
      };

      homeConfigurations.rubicon = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = linuxPkgs;
        extraSpecialArgs = { inherit self inputs; };
        modules = [ ./hosts/rubicon.nix ];
      };

      formatter.${system} = pkgs.nixfmt-tree;
      formatter.${linuxSystem} = linuxPkgs.nixfmt-tree;

      packages.${system} = {
        default = apollo;
        inherit (pkgs) google-sans-flex;
      };

      packages.${linuxSystem} = {
        default = rubicon;
        inherit gotham;
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
          linuxPkgs.runCommand "eval-rubicon"
            {
              drv = builtins.unsafeDiscardStringContext rubicon.drvPath;
            }
            ''
              test -n "$drv"
              touch $out
            '';

        eval-gotham =
          linuxPkgs.runCommand "eval-gotham"
            {
              drv = builtins.unsafeDiscardStringContext gotham.drvPath;
            }
            ''
              test -n "$drv"
              touch $out
            '';
      };

      checks.${system} = {
        lint = lint pkgs;

        eval =
          pkgs.runCommand "eval-apollo"
            {
              drv = builtins.unsafeDiscardStringContext apollo.drvPath;
            }
            ''
              test -n "$drv"
              touch $out
            '';

        smoke =
          pkgs.runCommand "smoke-apollo"
            {
              brewfile = self.darwinConfigurations.apollo.config.homebrew.brewfile;
            }
            ''
              system=${apollo}

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
