{
  config,
  pkgs,
  ...
}:

let
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;

  shell = import ../lib/shell.nix;

  warningFreePercent = 15;
  cleanupFreePercent = 10;
  emergencyFreePercent = 5;
  stagingMaxKiB = 8 * 1024 * 1024;

  logDir = "${home}/Library/Logs/local-maintenance";
  stateDir = "${home}/.local/state/local-maintenance";
  cacheStateDir = config.services.nix-cache-push.stateDir;
  stagingDir = config.services.nix-cache-push.stagingDir;
  brew = "${config.homebrew.prefix}/bin/brew";

  userMaintenance = pkgs.writeShellApplication {
    name = "local-maintenance";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.dust
      pkgs.gawk
      pkgs.go
      pkgs.nodejs
      pkgs.uv
    ];
    text = ''
      log_dir=${pkgs.lib.escapeShellArg logDir}
      state_dir=${pkgs.lib.escapeShellArg stateDir}
      cache_state_dir=${pkgs.lib.escapeShellArg cacheStateDir}
      staging_dir=${pkgs.lib.escapeShellArg stagingDir}
      out_log="$log_dir/out.log"
      err_log="$log_dir/err.log"

      mkdir -p "$log_dir" "$state_dir"

      ${shell.rotateLog}
      ${shell.dataVolumeFreePercent}

      if [ "''${LOCAL_MAINTENANCE_BACKGROUND:-0}" = 1 ]; then
        rotate_log "$out_log"
        rotate_log "$err_log"
        exec >>"$out_log" 2>>"$err_log"
      fi

      now=$(date +%s)

      due() {
        local stamp=$1
        local interval=$2
        local last=0
        if [ -r "$stamp" ]; then
          read -r last < "$stamp" || last=0
        fi
        [ "$((now - last))" -ge "$interval" ]
      }

      mark_done() {
        printf '%s\n' "$now" > "$1"
      }

      notify() {
        /usr/bin/osascript -e "display notification \"$1\" with title \"local maintenance\"" >/dev/null
      }

      if ! free_percent=$(data_volume_free_percent); then
        echo "could not determine data-volume usage" >&2
        exit 1
      fi

      show_stamp() {
        local label=$1
        local stamp=$2
        local value
        if [ -r "$stamp" ]; then
          read -r value < "$stamp"
          printf '%-24s %s\n' "$label" "$(date -d "@$value" -Iseconds)"
        else
          printf '%-24s never\n' "$label"
        fi
      }

      if [ "''${1:-}" = "--status" ]; then
        printf '%-24s %s%%\n' "data volume free" "$free_percent"
        /usr/bin/du -sh \
          "$HOME/Library/Caches/go-build" \
          "$HOME/go/pkg/mod" \
          "$HOME/Library/Caches/Homebrew" \
          "$HOME/.cache/uv" \
          "$staging_dir" 2>/dev/null || true
        show_stamp "last uv prune" "$state_dir/uv-prune"
        show_stamp "last npm verify" "$state_dir/npm-verify"
        show_stamp "last brew cleanup" "$state_dir/brew-cleanup"
        show_stamp "last go cache cleanup" "$state_dir/go-cache-clean"
        show_stamp "last go module cleanup" "$state_dir/go-modcache-clean"
        show_stamp "last cache upload" "$cache_state_dir/last-success"
        exit 0
      fi

      if [ "$#" -ne 0 ]; then
        echo "usage: local-maintenance [--status]" >&2
        exit 2
      fi

      echo "$(date -Iseconds) starting with $free_percent% free"

      if due "$state_dir/uv-prune" $((7 * 86400)); then
        if uv cache prune; then
          mark_done "$state_dir/uv-prune"
        fi
      fi

      if due "$state_dir/npm-verify" $((30 * 86400)); then
        if npm cache verify; then
          mark_done "$state_dir/npm-verify"
        fi
      fi

      if due "$state_dir/brew-cleanup" $((30 * 86400)); then
        if ${pkgs.lib.escapeShellArg brew} cleanup --prune=all; then
          mark_done "$state_dir/brew-cleanup"
        fi
      fi

      if [ "$free_percent" -lt ${toString warningFreePercent} ]; then
        dust -d 1 -n 40 -c -P \
          "$HOME/Library/Caches" "$HOME/.cache" "$HOME/go" "$HOME/.cargo" \
          > "$log_dir/storage-report.txt" 2>>"$err_log" || true
        notify "disk space is low: $free_percent% free"
      fi

      if [ "$free_percent" -lt ${toString cleanupFreePercent} ]; then
        if [ -d /Volumes/onyx ]; then
          /usr/bin/find /Volumes/onyx -maxdepth 5 -type d -name ".build" -mtime +14 -prune -exec rm -rf {} + 2>/dev/null || true
        fi
        if [ -d "$HOME/Library/Developer/Xcode/DerivedData" ]; then
          /usr/bin/find "$HOME/Library/Developer/Xcode/DerivedData" -mindepth 1 -maxdepth 1 -mtime +14 -exec rm -rf {} + 2>/dev/null || true
        fi
        if [ -d "$HOME/.hermes/installs" ]; then
          /usr/bin/find "$HOME/.hermes/installs" -mindepth 1 -maxdepth 1 -mtime +14 -exec rm -rf {} + 2>/dev/null || true
        fi

        if due "$state_dir/go-cache-clean" $((3 * 86400)); then
          if go clean -cache; then
            mark_done "$state_dir/go-cache-clean"
          fi
        fi

        if [ -d "$staging_dir" ] && [ -r "$cache_state_dir/last-success" ]; then
          staging_kib=$(/usr/bin/du -sk "$staging_dir" | awk '{print $1}')
          read -r last_success < "$cache_state_dir/last-success" || last_success=0
          if [ "$staging_kib" -gt ${toString stagingMaxKiB} ] \
            && [ "$((now - last_success))" -lt $((30 * 86400)) ] \
            && mkdir "$cache_state_dir/lock" 2>/dev/null; then
            (
              trap 'rmdir "$cache_state_dir/lock"' EXIT
              case "$staging_dir" in
                ${pkgs.lib.escapeShellArg stagingDir})
                  /usr/bin/find "$staging_dir" -mindepth 1 -delete
                  echo "cleared oversized nix-cache staging directory"
                  ;;
                *)
                  echo "refusing unexpected staging directory: $staging_dir" >&2
                  ;;
              esac
            )
          fi
        fi
      fi

      if [ "$free_percent" -lt ${toString emergencyFreePercent} ] \
        && due "$state_dir/go-modcache-clean" $((7 * 86400)); then
        if go clean -modcache; then
          mark_done "$state_dir/go-modcache-clean"
        fi
      fi

      echo "$(date -Iseconds) finished"
    '';
  };

  nixPressureGc = pkgs.writeShellApplication {
    name = "nix-pressure-gc";
    runtimeInputs = [
      config.nix.package
      pkgs.gawk
    ];
    text = ''
      ${shell.dataVolumeFreePercent}

      if ! free_percent=$(data_volume_free_percent); then
        /usr/bin/logger -t nix-pressure-gc "could not determine data-volume usage"
        exit 1
      fi

      if [ "$free_percent" -ge ${toString cleanupFreePercent} ]; then
        exit 0
      fi

      nix-collect-garbage --delete-older-than 7d 2>&1 \
        | /usr/bin/logger -t nix-pressure-gc
    '';
  };

  maintenanceStatus = pkgs.writeShellApplication {
    name = "maintenance-status";
    runtimeInputs = [ userMaintenance ];
    text = ''
      exec local-maintenance --status
    '';
  };
in
{
  system.activationScripts.extraActivation.text = ''
    install -d -o ${user} -g staff "${logDir}"
    install -d -o ${user} -g staff "${stateDir}"
  '';

  launchd.user.agents.local-maintenance = {
    serviceConfig = {
      Label = "org.${user}.local-maintenance";
      ProgramArguments = [ "${userMaintenance}/bin/local-maintenance" ];
      RunAtLoad = true;
      StartCalendarInterval = {
        Hour = 10;
        Minute = 0;
      };
      Nice = 10;
      LowPriorityIO = true;
      ProcessType = "Background";
      EnvironmentVariables = {
        HOME = home;
        LOCAL_MAINTENANCE_BACKGROUND = "1";
        PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };

  launchd.daemons.nix-pressure-gc = {
    command = "${nixPressureGc}/bin/nix-pressure-gc";
    serviceConfig = {
      Label = "org.nixos.nix-pressure-gc";
      RunAtLoad = true;
      StartInterval = 21600;
      Nice = 10;
      LowPriorityIO = true;
      ProcessType = "Background";
    };
  };

  environment.systemPackages = [
    userMaintenance
    maintenanceStatus
  ];
}
