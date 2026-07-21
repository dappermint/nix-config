{
  pkgs,
  lib,
  self,
  config,
  system,
  primaryUsername,
  primaryHomeDirectory,
  ...
}:

let
  builderKey = "${primaryHomeDirectory}/.ssh/nix_builder";
  geistMonoNerdFontOverlay = final: _: {
    geist-mono-nerd-font = final.stdenvNoCC.mkDerivation {
      pname = "geist-mono-nerd-font";
      inherit (final.geist-font) version;

      dontUnpack = true;

      nativeBuildInputs = [ final.nerd-font-patcher ];

      buildPhase = ''
        runHook preBuild

        mkdir patched
        for style in Regular Italic Bold BoldItalic; do
          nerd-font-patcher \
            --complete \
            --careful \
            --mono \
            --no-progressbars \
            --outputdir patched \
            --quiet \
            "${final.geist-font}/share/fonts/opentype/GeistMono-$style.otf"
        done

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        install -d "$out/share/fonts/opentype"
        install -m444 patched/*.otf "$out/share/fonts/opentype/"

        runHook postInstall
      '';

      meta = {
        description = "Geist Mono patched with Nerd Fonts glyphs";
        homepage = "https://vercel.com/font";
        license = with lib.licenses; [
          mit
          ofl
        ];
        platforms = lib.platforms.all;
      };
    };
  };
in
{
  networking.hostName = "meatwizard";
  networking.computerName = "meatwizard";
  networking.localHostName = "meatwizard";

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = system;
  nixpkgs.overlays = [ geistMonoNerdFontOverlay ];

  system.primaryUser = primaryUsername;
  system.stateVersion = 6;
  system.configurationRevision = self.rev or self.dirtyRev or null;
  users.users.${primaryUsername}.home = primaryHomeDirectory;

  documentation.enable = false;
  system.tools.darwin-uninstaller.enable = false;

  nix = {
    package = pkgs.lixPackageSets.lix_2_95.lix;

    channel.enable = false;
    registry = lib.mkForce { };

    settings = {
      experimental-features = [
        "flakes"
        "nix-command"
        "pipe-operator"
      ];

      always-allow-substitutes = true;
      builders-use-substitutes = true;

      auto-optimise-store = true;
      keep-outputs = false;
      keep-derivations = false;

      min-free = 21474836480;
      max-free = 42949672960;

      max-jobs = "auto";
      cores = 0;

      connect-timeout = 5;
      download-attempts = 3;
      fallback = true;

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

      trusted-users = [
        "root"
        primaryUsername
      ];
    };

    envVars = {
      AWS_SHARED_CREDENTIALS_FILE = "${primaryHomeDirectory}/.aws/credentials";
    };

    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "nix-builder-arm.clownway.org";
        sshUser = "builder";
        sshKey = builderKey;
        systems = [ "aarch64-linux" ];
        maxJobs = 4;
        speedFactor = 2;
        supportedFeatures = [
          "kvm"
          "big-parallel"
          "benchmark"
        ];
      }
      {
        hostName = "nix-builder-x86.clownway.org";
        sshUser = "builder";
        sshKey = builderKey;
        systems = [ "x86_64-linux" ];
        maxJobs = 4;
        speedFactor = 2;
        supportedFeatures = [
          "kvm"
          "big-parallel"
          "benchmark"
        ];
      }
    ];

    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 4;
        Minute = 0;
      };
      options = "--delete-older-than 7d";
    };

    linux-builder.enable = false;
  };

  system.activationScripts.postActivation.text = ''
    for prof in /nix/var/nix/profiles/system \
                /nix/var/nix/profiles/per-user/root/profile \
                /nix/var/nix/profiles/per-user/${primaryUsername}/profile \
                ${primaryHomeDirectory}/.local/state/nix/profiles/home-manager \
                ${primaryHomeDirectory}/.local/state/nix/profiles/profile; do
      if [ -e "$prof" ]; then
        ${config.nix.package}/bin/nix-env --profile "$prof" --delete-generations +3 || true
      fi
    done
  '';

  services.nix-cache-push.enable = true;

  programs.fish.enable = true;

  programs.nix-index.enable = true;

  security.pam.services.sudo_local.touchIdAuth = true;

  environment.etc."ssh/ssh_config.d/200-nix-builders.conf".text = ''
    Host nix-builder-arm.clownway.org nix-builder-x86.clownway.org
      User builder
      IdentityFile ${builderKey}
      IdentitiesOnly yes
      StrictHostKeyChecking accept-new
      UserKnownHostsFile /var/root/.ssh/known_hosts_builders
  '';
}
