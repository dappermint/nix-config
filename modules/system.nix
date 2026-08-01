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

  fonts.packages = [
    pkgs.geist-font
    pkgs.geist-mono-nerd-font
  ];

  system.primaryUser = primaryUsername;
  system.stateVersion = 6;
  system.configurationRevision = self.rev or self.dirtyRev or null;
  users.users.${primaryUsername}.home = primaryHomeDirectory;

  documentation.enable = false;
  system.tools.darwin-uninstaller.enable = false;

  nix = {
    package = pkgs.lixPackageSets.latest.lix;

    channel.enable = false;
    registry = lib.mkForce { };

    settings = {
      experimental-features = [
        "flakes"
        "nix-command"
        "pipe-operator"
      ];

      always-allow-substitutes = true;

      auto-optimise-store = true;
      keep-outputs = false;
      keep-derivations = false;

      min-free = 5368709120;
      max-free = 10737418240;

      max-jobs = "auto";
      cores = 0;

      connect-timeout = 5;
      download-attempts = 3;
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
      AWS_SHARED_CREDENTIALS_FILE = "${primaryHomeDirectory}/.aws/credentials";
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
                /nix/var/nix/profiles/per-user/${primaryUsername}/profile \
                ${primaryHomeDirectory}/.local/state/nix/profiles/home-manager \
                ${primaryHomeDirectory}/.local/state/nix/profiles/profile; do
      if [ -e "$prof" ]; then
        ${config.nix.package}/bin/nix-env --profile "$prof" --delete-generations +3 || true
      fi
    done
  '';

  services.nix-cache-push = {
    enable = true;
    safeSSIDs = [
      "petah tikva"
      "sbox_inet"
      "nibbler"
      "6ix7even"
    ];
  };

  programs.fish.enable = true;

  programs.nix-index.enable = true;

  security.pam.services.sudo_local.touchIdAuth = true;

  # ha.int.sandb0x.space round-robins onto two space-LAN-only A records that
  # black-hole from anywhere else, so pin it to the mesh address
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

}
