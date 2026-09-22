{ inputs, ... }:

let
  user = "dappy";
in
{
  imports = [
    ../modules/system.nix
    ../modules/packages.nix
    ../modules/homebrew.nix
    ../modules/defaults.nix
    ../modules/nix-cache-push.nix
    ../modules/maintenance.nix
    ../modules/github-runners.nix
    ../modules/sbx-backup-pull.nix
    inputs.nix-index-database.darwinModules.nix-index
    inputs.sops-nix.darwinModules.sops
    ../modules/gdrive-mount.nix
    ../modules/secrets.nix
    inputs.home-manager.darwinModules.home-manager
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  networking.hostName = "meatwizard";
  networking.computerName = "meatwizard";
  networking.localHostName = "meatwizard";

  system.stateVersion = 7;
  system.primaryUser = user;
  users.users.${user}.home = "/Users/${user}";

  services.nix-cache-push = {
    enable = true;
    safeSSIDs = [
      "petah tikva"
      "sbox_inet"
      "nibbler"
      "6ix7even"
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    users.${user} = import ../home/dappy.nix;
  };
}
