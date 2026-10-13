{
  pkgs,
  lib,
  self,
  inputs,
  config,
  ...
}:

let
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;
in
{
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [ (import ../overlays) ];

  fonts.packages = [
    pkgs.google-sans-flex
    pkgs.nerd-fonts.googlesanscode
  ];

  system.configurationRevision = self.rev or self.dirtyRev or null;

  documentation.enable = false;
  system.tools.darwin-uninstaller.enable = false;

  nix = {
    # ponytail: drop once nixpkgs-unstable has 31a68c07fe (lix -z,noexecstack breaks ld64)
    package = pkgs.lixPackageSets.latest.lix.overrideAttrs (o: {
      env = o.env // {
        NIX_LDFLAGS = "";
      };
    });

    channel.enable = false;

    # clearing the system registry does not stop `flake:nixpkgs` from resolving:
    # lix ships flake-registry = vendored, so bare `nix run nixpkgs#x` fetched a
    # second, unlocked nixpkgs. pin the entry to the locked input and turn the
    # vendored registry off, so the shorthand resolves to the store path the
    # system was already built from
    registry = lib.mkForce { nixpkgs.flake = inputs.nixpkgs; };

    settings = {
      experimental-features = [
        "flakes"
        "nix-command"
      ];

      flake-registry = "";

      always-allow-substitutes = true;

      # the daemon socket is the attack surface for the NAR parser CVEs, and
      # nothing but root and admins has any business on it here
      allowed-users = [
        "root"
        "@admin"
      ];

      # remote builds and `nix copy --no-check-sigs` are restricted settings:
      # the daemon silently ignores them from an untrusted user, so a build
      # aimed at a linux builder falls back to building locally and fails on
      # the architecture instead of saying why. Deploying x86_64-linux from
      # this machine needs them, and the primary user is the person doing it.
      #
      # This does mean this user can insert arbitrary paths into the store,
      # which is the actual cost. It is the same trust the user already has by
      # being able to edit and switch this configuration.
      # root is already in the upstream default; this only adds the operator
      trusted-users = [ user ];

      auto-optimise-store = true;
      keep-outputs = false;
      keep-derivations = false;

      min-free = 5368709120;
      max-free = 10737418240;

      max-jobs = "auto";
      cores = 0;

      connect-timeout = 5;
      download-attempts = 3;
      # off by default upstream. cache.nixos.org is behind fastly, and the
      # narinfo storm at the start of a switch is latency bound, not bandwidth
      # bound. set to false if a network that breaks QUIC stalls substitution
      http3 = true;
      fallback = true;
      log-format = "multiline-with-logs";
      log-lines = 50;

      narinfo-cache-positive-ttl = 86400;
      narinfo-cache-negative-ttl = 3600;
      tarball-ttl = 604800;

      secret-key-files = [ config.sops.secrets."nix-cache-priv-key".path ];

      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://cache.lix.systems"
        "s3://nix-cache-infra?region=eu-north-1&profile=nix-cache"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o="
        "nix-cache-conway:UzHXLOUOfz/ztSgyJ/v0J9BmbX0dLeCJVQp6lGpk78I="
      ];
    };

    envVars = {
      AWS_SHARED_CREDENTIALS_FILE = "${home}/.aws/credentials";
    };

    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 4;
        Minute = 0;
      };
      options = "--delete-older-than 7d";
    };
  };

  system.activationScripts.postActivation.text = ''
    for prof in /nix/var/nix/profiles/system \
                /nix/var/nix/profiles/per-user/root/profile \
                /nix/var/nix/profiles/per-user/${user}/profile \
                ${home}/.local/state/nix/profiles/home-manager \
                ${home}/.local/state/nix/profiles/profile; do
      if [ -e "$prof" ]; then
        ${config.nix.package}/bin/nix-env --profile "$prof" --delete-generations +3 || true
      fi
    done
  '';

  programs.fish.enable = true;

  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

  security.pam.services.sudo_local.touchIdAuth = true;
}
