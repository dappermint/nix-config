{
  pkgs,
  lib,
  config,
  ...
}:

let
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;

  shell = import ../lib/shell.nix;

  cfg = config.services.nix-cache-push;
  aws = "${config.homebrew.prefix}/bin/aws";

  pushScript = pkgs.writeShellApplication {
    name = "nix-cache-push";
    runtimeInputs = [
      config.nix.package
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
    ];
    text = ''
      mkdir -p "${cfg.logDir}" "${cfg.stateDir}"

      ${shell.rotateLog}

      if [ "''${NIX_CACHE_PUSH_BACKGROUND:-0}" = 1 ]; then
        rotate_log "${cfg.logDir}/out.log"
        rotate_log "${cfg.logDir}/err.log"
        exec >>"${cfg.logDir}/out.log" 2>>"${cfg.logDir}/err.log"
      fi

      FORCE=0
      DEFAULT_PATHS=0
      PATHS=()
      for arg in "$@"; do
        case "$arg" in
          --force) FORCE=1 ;;
          *) PATHS+=("$arg") ;;
        esac
      done
      if [ ''${#PATHS[@]} -eq 0 ]; then
        DEFAULT_PATHS=1
        PATHS=(/run/current-system)
      fi

      current_system=$(readlink /run/current-system)
      if [ "$DEFAULT_PATHS" -eq 1 ] && [ "$FORCE" -ne 1 ] \
        && [ -r "${cfg.stateDir}/last-system" ] \
        && [ "$(cat "${cfg.stateDir}/last-system")" = "$current_system" ]; then
        echo "system already uploaded; skipping"
        exit 0
      fi

      if [ "$FORCE" -ne 1 ]; then
        IFACE=$(/sbin/route -n get default 2>/dev/null | awk '/interface:/ {print $2}' || true)
        if [ -z "''${IFACE:-}" ]; then
          echo "no default route; skipping" >&2
          exit 0
        fi
        case "$IFACE" in
          en*|bridge*) : ;;
          *)
            echo "iface $IFACE not whitelisted; skipping" >&2
            exit 0
            ;;
        esac
        # networksetup -getairportnetwork reports "not associated" while
        # connected on current macos, and ipconfig redacts the ssid, so an
        # empty read used to skip the allowlist entirely. fail closed instead
        if /usr/sbin/ipconfig getsummary "$IFACE" 2>/dev/null | grep -q 'InterfaceType : WiFi'; then
          SSID=$(/usr/sbin/system_profiler SPAirPortDataType 2>/dev/null \
            | awk '/Current Network Information:/ { getline; sub(/^ +/, ""); sub(/:$/, ""); print; exit }' || true)
          if [ -z "''${SSID:-}" ] || [ "$SSID" = "<redacted>" ]; then
            echo "wifi on $IFACE but ssid unreadable; skipping" >&2
            exit 0
          fi
          OK=0
          # shellcheck disable=SC2043
          for s in ${lib.concatStringsSep " " (map lib.escapeShellArg cfg.safeSSIDs)}; do
            [ "$SSID" = "$s" ] && OK=1
          done
          if [ "$OK" -ne 1 ]; then
            echo "wifi '$SSID' not in safe list; skipping" >&2
            exit 0
          fi
        fi
      fi

      if ! mkdir "${cfg.stateDir}/lock" 2>/dev/null; then
        echo "another cache operation is running; skipping"
        exit 0
      fi
      trap 'rmdir "${cfg.stateDir}/lock"' EXIT

      mkdir -p "${cfg.stagingDir}"
      echo "staging closure -> ${cfg.stagingDir}"
      nix copy --to "file://${cfg.stagingDir}?compression=zstd&compression-level=${toString cfg.compressionLevel}&parallel-compression=true" "''${PATHS[@]}"

      echo "syncing -> s3://${cfg.bucket}"
      ${aws} --profile "${cfg.profile}" --region "${cfg.region}" \
        s3 sync "${cfg.stagingDir}" "s3://${cfg.bucket}/" --no-progress

      if [ "$DEFAULT_PATHS" -eq 1 ]; then
        printf '%s\n' "$current_system" > "${cfg.stateDir}/last-system"
      fi
      date +%s > "${cfg.stateDir}/last-success"
    '';
  };
in
{
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
      default = "${home}/.cache/nix-cache-staging";
      description = "Local staging directory for closures.";
    };

    logDir = lib.mkOption {
      type = lib.types.path;
      default = "${home}/Library/Logs/nix-cache-push";
      description = "Directory for launchd logs.";
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "${home}/.local/state/nix-cache-push";
      description = "Directory for upload state.";
    };

    # deliberately has no default: an unset allowlist would silently skip every
    # upload made over wi-fi, so make it an eval error instead
    safeSSIDs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Wi-Fi SSIDs where caching is permitted.";
    };

    intervalSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10800; # 3 hours
      description = "Sync interval in seconds.";
    };

    compressionLevel = lib.mkOption {
      type = lib.types.ints.between 1 19;
      default = 12;
      description = ''
        ZSTD compression level used for closures (1-19). 19 saturated five
        cores for minutes on every run and bought a few percent over 12.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.extraActivation.text = ''
      install -d -o ${user} -g staff "${cfg.logDir}"
      install -d -o ${user} -g staff "${cfg.stateDir}"
    '';

    launchd.user.agents.nix-cache-push = {
      serviceConfig = {
        Label = "org.${user}.nix-cache-push";
        ProgramArguments = [ "${pushScript}/bin/nix-cache-push" ];
        StartInterval = cfg.intervalSeconds;
        RunAtLoad = false;
        Nice = 10;
        LowPriorityIO = true;
        EnvironmentVariables = {
          HOME = home;
          AWS_SHARED_CREDENTIALS_FILE = "${home}/.aws/credentials";
          AWS_CONFIG_FILE = "${home}/.aws/config";
          NIX_CACHE_PUSH_BACKGROUND = "1";
          PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
      };
    };

    environment.systemPackages = [ pushScript ];
  };
}
