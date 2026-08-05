{ lib, inputs, ... }:

let
  user = "dappy";
in
{
  imports = [
    ../modules/system.nix
    ../modules/packages.nix
    ../modules/homebrew.nix
    ../modules/defaults.nix
    ../modules/aerospace.nix
    ../modules/nix-cache-push.nix
    ../modules/maintenance.nix
    ../modules/github-runners.nix
    inputs.sops-nix.darwinModules.sops
    ../modules/secrets.nix
    inputs.home-manager.darwinModules.home-manager
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  networking.hostName = "meatwizard";
  networking.computerName = "meatwizard";
  networking.localHostName = "meatwizard";

  system.stateVersion = 6;
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

  # ha.int.sandb0x.space round-robins onto two space-LAN-only A records that
  # black-hole from anywhere else, so pin it to the mesh address. this has to
  # stay in cleartext: /etc/hosts is baked at eval time, so it cannot read a
  # sops secret the way the runtime inventory does
  environment.etc."hosts" = {
    knownSha256Hashes = [
      "c7dd0e2ed261ce76d76f852596c5b54026b9a894fa481381ffd399b556c0e2da"
    ];
    text = ''
      127.0.0.1	localhost
      255.255.255.255	broadcasthost
      ::1	localhost

      10.212.240.104	ha.int.sandb0x.space
    '';
  };

  # the networking activation script unconditionally moves
  # /etc/hosts.before-nix-darwin back over the symlink that /etc setup just
  # made, so relink once it has run
  system.activationScripts.networking.text = lib.mkAfter ''
    ln -sfn /etc/static/hosts /etc/hosts
  '';

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    users.${user} = import ../home/dappy.nix;
  };
}
