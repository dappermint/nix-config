{
  description = "meatwizard nix-darwin system flake";

  inputs = {
    nixpkgs.url = "git+file:///Users/dappy/Code/nixpkgs?ref=nixpkgs-unstable&shallow=1";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, sops-nix }: {
    darwinConfigurations."meatwizard" = nix-darwin.lib.darwinSystem {
      specialArgs = { inherit self inputs; };
      modules = [
        ./modules/system.nix
        ./modules/packages.nix
        ./modules/homebrew.nix
        ./modules/defaults.nix
        ./modules/aerospace.nix
        ./modules/nix-cache-push.nix
        sops-nix.darwinModules.sops
        ./modules/secrets.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.dappy = import ./home/dappy.nix;
        }
      ];
    };
  };
}
