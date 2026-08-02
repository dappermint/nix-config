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
    {
      self,
      nix-darwin,
      nixpkgs,
      home-manager,
      sops-nix,
      mac-cleaner,
      ...
    }:
    let
      system = "aarch64-darwin";
      primaryUsername = "dappy";
      primaryHomeDirectory = "/Users/${primaryUsername}";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      darwinConfigurations."meatwizard" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit
            self
            system
            primaryUsername
            primaryHomeDirectory
            mac-cleaner
            ;
        };
        modules = [
          ./modules/system.nix
          ./modules/packages.nix
          ./modules/homebrew.nix
          ./modules/defaults.nix
          ./modules/aerospace.nix
          ./modules/nix-cache-push.nix
          ./modules/maintenance.nix
          sops-nix.darwinModules.sops
          ./modules/secrets.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.extraSpecialArgs = {
              inherit system primaryHomeDirectory;
            };
            home-manager.users.${primaryUsername} = import ./home/dappy.nix;
          }
        ];
      };

      formatter.${system} = pkgs.nixfmt;

      checks.${system}.lint =
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
    };
}
