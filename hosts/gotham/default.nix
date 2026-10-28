{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:

let
  keys = import ../../lib/keys.nix;
  user = "dappy";
in
{
  imports = [
    ./hardware.nix
    ./network.nix
    ./smarthome.nix
    ./services.nix
    inputs.sops-nix.nixosModules.sops
    inputs.abode.nixosModules.default
  ];

  nixpkgs.hostPlatform = "aarch64-linux";

  nixpkgs.overlays = [ (import ../../overlays) ];

  networking.hostName = "gotham";

  system.stateVersion = "26.11";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
    # authorized_keys below stays as the fallback if the ca key is ever lost
    extraConfig = ''
      TrustedUserCAKeys /etc/ssh/ssh_user_ca.pub
      HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
    '';
  };
  environment.etc."ssh/ssh_user_ca.pub".text = "${keys.ca} dappy-ca\n";
  # public, signed with: ssh-keygen -s dappy-ca.pub -U -h -I gotham -n gotham -V +52w
  environment.etc."ssh/ssh_host_ed25519_key-cert.pub".source = ./ssh_host_ed25519_key-cert.pub;

  sops = {
    defaultSopsFile = "${self}/secrets/gotham.yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.garage_backup_env = { };
    secrets.kanidm_idm_admin_password.owner = "kanidm";
    secrets.kanidm_vaultwarden_secret.owner = "kanidm";
    secrets.kanidm_gatus_secret.owner = "kanidm";
    secrets.syncthing_gui_password.owner = "syncthing";
    secrets.wifi_env.owner = "wpa_supplicant";
    secrets.ninerouter_env.restartUnits = [ "ninerouter.service" ];
    secrets.netbird_setup_key = { };
    # the client side reads the same secret, but only as an env var
    templates."vaultwarden.env".content = ''
      SSO_CLIENT_SECRET=${config.sops.placeholder.kanidm_vaultwarden_secret}
    '';
    templates."vaultwarden.env".restartUnits = [ "vaultwarden.service" ];
    templates."gatus.env".content = ''
      GATUS_OIDC_SECRET=${config.sops.placeholder.kanidm_gatus_secret}
    '';
    templates."gatus.env".restartUnits = [ "gatus.service" ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    keys.ed25519
    keys.enclave
  ];

  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      keys.ed25519
      keys.enclave
    ];
  };

  services.journald.settings.Journal.SystemMaxUse = "200M";

  documentation.enable = false;

  nix.package = inputs.lix.packages.${pkgs.stdenv.hostPlatform.system}.default;

  nix.settings = {
    experimental-features = [
      "flakes"
      "nix-command"
    ];
    auto-optimise-store = true;
    extra-substituters = [ "https://cache.lix.systems" ];
    extra-trusted-public-keys = [
      "cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o="
    ];
    allowed-users = [
      "root"
      "@wheel"
    ];
    max-jobs = 1;
    cores = 3;
  };

  systemd.services.nix-daemon.serviceConfig = {
    CPUWeight = 20;
    IOWeight = 20;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  security.sudo.wheelNeedsPassword = lib.mkDefault false;
}
