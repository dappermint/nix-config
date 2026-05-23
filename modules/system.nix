{ pkgs, lib, self, ... }:

{
  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.primaryUser = "dappy";
  system.stateVersion = 6;
  system.configurationRevision = self.rev or self.dirtyRev or null;

  nix = {
    package = pkgs.lixPackageSets.lix_2_95.lix;

    channel.enable = false;
    registry = lib.mkForce {};

    settings = {
      experimental-features = "nix-command flakes";

      always-allow-substitutes = true;
      builders-use-substitutes = true;

      auto-optimise-store = true;
      keep-outputs = false;
      keep-derivations = false;

      min-free = 1073741824;
      max-free = 10737418240;

      max-jobs = "auto";
      cores = 0;

      connect-timeout = 5;
      download-attempts = 3;
      fallback = true;

      narinfo-cache-positive-ttl = 86400;
      narinfo-cache-negative-ttl = 3600;
      tarball-ttl = 604800;

      secret-key-files = "/var/root/nix-cache-priv.pem";
      # post-build-hook = toString (pkgs.writeShellScript "upload-to-cache" ''
      #   set -eu
      #   set -f
      #   export IFS=' '
      #   export AWS_SHARED_CREDENTIALS_FILE=/Users/dappy/.aws/credentials
      #   exec ${pkgs.nix}/bin/nix copy --to \
      #     's3://nix-cache-infra?region=eu-north-1&profile=nix-cache-writer&compression=zstd&compression-level=19&parallel-compression=true' $OUT_PATHS
      # '');

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

      trusted-users = [ "root" "dappy" ];
    };

    envVars = {
      AWS_SHARED_CREDENTIALS_FILE = "/Users/dappy/.aws/credentials";
    };

    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "nix-builder-arm.clownway.org";
        sshUser = "builder";
        sshKey = "/Users/dappy/.ssh/nix_builder";
        systems = [ "aarch64-linux" ];
        maxJobs = 4;
        speedFactor = 2;
        supportedFeatures = [ "kvm" "big-parallel" "benchmark" ];
      }
      {
        hostName = "nix-builder-x86.clownway.org";
        sshUser = "builder";
        sshKey = "/Users/dappy/.ssh/nix_builder";
        systems = [ "x86_64-linux" ];
        maxJobs = 4;
        speedFactor = 2;
        supportedFeatures = [ "kvm" "big-parallel" "benchmark" ];
      }
    ];

    gc = {
      automatic = true;
      interval = { Weekday = 0; };
      options = "--delete-older-than 7d";
    };

    optimise = {
      automatic = true;
      interval = { Weekday = 0; };
    };

    linux-builder.enable = false;
  };

  system.activationScripts.trimGenerations.text = ''
    for prof in /nix/var/nix/profiles/system \
                /nix/var/nix/profiles/per-user/root/profile \
                /nix/var/nix/profiles/per-user/dappy/profile \
                /Users/dappy/.local/state/nix/profiles/home-manager \
                /Users/dappy/.local/state/nix/profiles/profile; do
      if [ -e "$prof" ]; then
        ${pkgs.nix}/bin/nix-env --profile "$prof" --delete-generations +1 || true
      fi
    done
  '';

  programs.fish.enable = true;

  security.pam.services.sudo_local.touchIdAuth = true;

  fonts.packages = [ pkgs.nerd-fonts.fira-code ];

  environment.etc."ssh/ssh_config.d/200-nix-builders.conf".text = ''
    Host nix-builder-arm.clownway.org nix-builder-x86.clownway.org
      User builder
      IdentityFile /Users/dappy/.ssh/nix_builder
      IdentitiesOnly yes
      StrictHostKeyChecking accept-new
      UserKnownHostsFile /var/root/.ssh/known_hosts_builders
  '';
}
