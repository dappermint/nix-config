{ pkgs, lib, config, ... }:

let
  cfg = config.services.nix-cache-push;

  pushScript = pkgs.writeShellApplication {
    name = "nix-cache-push";
    runtimeInputs = with pkgs; [ awscli2 config.nix.package coreutils gnugrep gawk gnused ];
    text = ''
      set -euo pipefail

      FORCE=0
      PATHS=()
      for arg in "$@"; do
        case "$arg" in
          --force) FORCE=1 ;;
          *) PATHS+=("$arg") ;;
        esac
      done
      [ ''${#PATHS[@]} -eq 0 ] && PATHS=(/run/current-system)

      if [ "$FORCE" -ne 1 ]; then
        IFACE=$(/sbin/route -n get default 2>/dev/null | awk '/interface:/ {print $2}' || true)
        if [ -z "''${IFACE:-}" ]; then
          echo "no default route; skipping" >&2; exit 0
        fi
        case "$IFACE" in
          en*|bridge*) : ;;
          *) echo "iface $IFACE not whitelisted; skipping" >&2; exit 0 ;;
        esac
        SSID=$(/usr/sbin/networksetup -getairportnetwork "$IFACE" 2>/dev/null \
          | sed -E 's/^Current Wi-Fi Network: //' || true)
        if [ -n "''${SSID:-}" ] && [ "$SSID" != "You are not associated with an AirPort network." ]; then
          OK=0
          # shellcheck disable=SC2043
          for s in ${lib.concatStringsSep " " (map lib.escapeShellArg cfg.safeSSIDs)}; do
            [ "$SSID" = "$s" ] && OK=1
          done
          if [ "$OK" -ne 1 ]; then
            echo "wifi '$SSID' not in safe list; skipping" >&2; exit 0
          fi
        fi
      fi

      mkdir -p "${cfg.stagingDir}"
      echo "staging closure -> ${cfg.stagingDir}"
      nix copy --to "file://${cfg.stagingDir}?compression=zstd&compression-level=${toString cfg.compressionLevel}&parallel-compression=true" "''${PATHS[@]}"

      echo "syncing -> s3://${cfg.bucket}"
      aws --profile "${cfg.profile}" --region "${cfg.region}" \
        s3 sync "${cfg.stagingDir}" "s3://${cfg.bucket}/" --no-progress
    '';
  };
in {
  options.services.nix-cache-push = {
    enable = lib.mkEnableOption "nix-cache-push service";

    profile = lib.mkOption {
      type = lib.types.str;
      default = "nix-cache-writer";
      description = "AWS CLI profile name to use.";
    };

    bucket = lib.mkOption {
      type = lib.types.str;
      default = "nix-cache-infra";
      description = "S3 bucket to sync to.";
    };

    region = lib.mkOption {
      type = lib.types.str;
      default = "eu-north-1";
      description = "AWS region of the S3 bucket.";
    };

    stagingDir = lib.mkOption {
      type = lib.types.path;
      default = "/Users/${config.system.primaryUser}/.cache/nix-cache-staging";
      description = "Local staging directory for closures.";
    };

    logDir = lib.mkOption {
      type = lib.types.path;
      default = "/Users/${config.system.primaryUser}/Library/Logs/nix-cache-push";
      description = "Directory for launchd logs.";
    };

    safeSSIDs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "_PUT_HOME_SSID_HERE_" ];
      description = "Wi-Fi SSIDs where caching is permitted.";
    };

    intervalSeconds = lib.mkOption {
      type = lib.types.int;
      default = 10800; # 3 hours
      description = "Sync interval in seconds.";
    };

    compressionLevel = lib.mkOption {
      type = lib.types.int;
      default = 19;
      description = "ZSTD compression level used for closures (1-19).";
    };
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.nixCachePushLogDir.text = ''
      mkdir -p "${cfg.logDir}"
      chown ${config.system.primaryUser}:staff "${cfg.logDir}" || true
    '';

    launchd.user.agents.nix-cache-push = {
      serviceConfig = {
        Label = "org.dappy.nix-cache-push";
        ProgramArguments = [ "${pushScript}/bin/nix-cache-push" ];
        StartInterval = cfg.intervalSeconds;
        RunAtLoad = false;
        StandardOutPath = "${cfg.logDir}/out.log";
        StandardErrorPath = "${cfg.logDir}/err.log";
        Nice = 10;
        LowPriorityIO = true;
        EnvironmentVariables = {
          HOME = "/Users/${config.system.primaryUser}";
          AWS_SHARED_CREDENTIALS_FILE = "/Users/${config.system.primaryUser}/.aws/credentials";
          AWS_CONFIG_FILE = "/Users/${config.system.primaryUser}/.aws/config";
          PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
      };
    };

    environment.systemPackages = [ pushScript ];
  };
}
