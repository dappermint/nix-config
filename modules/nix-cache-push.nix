{ pkgs, lib, ... }:

let
  cfg = {
    profile = "nix-cache-writer";
    bucket = "nix-cache-infra";
    region = "eu-north-1";
    staging = "/Users/dappy/.cache/nix-cache-staging";
    safeSSIDs = [ "_PUT_HOME_SSID_HERE_" ];
    intervalSeconds = 3 * 60 * 60;
    logDir = "/Users/dappy/Library/Logs/nix-cache-push";
  };

  pushScript = pkgs.writeShellApplication {
    name = "nix-cache-push";
    runtimeInputs = with pkgs; [ awscli2 nix coreutils gnugrep gawk gnused ];
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

      mkdir -p ${cfg.staging}
      echo "staging closure -> ${cfg.staging}"
      nix copy --to "file://${cfg.staging}?compression=zstd&compression-level=19&parallel-compression=true" "''${PATHS[@]}"

      echo "syncing -> s3://${cfg.bucket}"
      aws --profile ${cfg.profile} --region ${cfg.region} \
        s3 sync ${cfg.staging} s3://${cfg.bucket}/ --no-progress
    '';
  };
in {
  system.activationScripts.nixCachePushLogDir.text = ''
    mkdir -p ${cfg.logDir}
    chown dappy:staff ${cfg.logDir} || true
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
        HOME = "/Users/dappy";
        AWS_SHARED_CREDENTIALS_FILE = "/Users/dappy/.aws/credentials";
        AWS_CONFIG_FILE = "/Users/dappy/.aws/config";
        PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };

  environment.systemPackages = [ pushScript ];
}
