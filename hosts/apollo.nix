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
    ../modules/kanata.nix
    inputs.home-manager.darwinModules.home-manager
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  networking.hostName = "apollo";
  networking.computerName = "apollo";
  networking.localHostName = "apollo";

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

  services.kanata.enable = true;

  launchd.daemons.dev-volume-unlock = {
    script = ''
      target=$(/usr/sbin/diskutil info "onyx" 2>/dev/null | awk -F': *' '/Volume UUID:/{print $2}')
      if [ -n "$target" ]; then
        pass=$(/usr/bin/security find-generic-password -s "$target" -w 2>/dev/null || /usr/bin/security find-generic-password -s "onyx" -w 2>/dev/null || /usr/bin/security find-generic-password -s "93FCCC39-80B5-4DF9-91C6-85534DEC4CE2" -w 2>/dev/null || true)
        if [ -n "$pass" ]; then
          echo "$pass" | /usr/sbin/diskutil apfs unlockVolume "$target" -stdinpassphrase || true
        fi
      fi
    '';
    serviceConfig.RunAtLoad = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    backupFileExtension = "hm-backup";
    users.${user} = import ../home/dappy.nix;
  };
}
