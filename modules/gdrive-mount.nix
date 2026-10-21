{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;
  mountPoint = "${home}/GoogleDrive";
  stateDir = "${home}/.local/state/rclone";

  mountScript = pkgs.writeShellApplication {
    name = "gdrive-mount";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.rclone
    ];
    text = ''
      mkdir -p "${mountPoint}"
      # rclone saves refreshed tokens back into its config, and the sops
      # render under /run/secrets is root-owned
      install -d -m 700 "${stateDir}"
      install -m 600 "${config.sops.templates."rclone.conf".path}" "${stateDir}/rclone.conf"

      if /sbin/mount | grep -q "${mountPoint}"; then
        echo "Google Drive is already mounted at ${mountPoint}"
        exit 0
      fi

      echo "Mounting Google Drive to ${mountPoint} via rclone nfsmount..."
      exec rclone nfsmount gdrive: "${mountPoint}" \
        --config "${stateDir}/rclone.conf" \
        --vfs-cache-mode full \
        --vfs-cache-max-size 10G \
        --vfs-cache-max-age 24h \
        --dir-cache-time 15m \
        --noappledouble \
        --volname "Google Drive"
    '';
  };

  unmountScript = pkgs.writeShellApplication {
    name = "gdrive-umount";
    runtimeInputs = [ pkgs.gnugrep ];
    text = ''
      if /sbin/mount | grep -q "${mountPoint}"; then
        echo "Unmounting ${mountPoint}..."
        /sbin/umount "${mountPoint}"
      else
        echo "${mountPoint} is not mounted."
      fi
    '';
  };
in
{
  options.services.gdrive-mount.enable = lib.mkEnableOption "the rclone google drive mount";

  config = lib.mkIf config.services.gdrive-mount.enable {
    environment.systemPackages = [
      mountScript
      unmountScript
    ];

    launchd.user.agents.gdrive-mount = {
      serviceConfig = {
        Label = "org.${user}.gdrive-mount";
        ProgramArguments = [ "${mountScript}/bin/gdrive-mount" ];
        RunAtLoad = true;
        KeepAlive.SuccessfulExit = false;
        ThrottleInterval = 300;
        ProcessType = "Background";
        StandardOutPath = "${home}/Library/Logs/gdrive-mount.log";
        StandardErrorPath = "${home}/Library/Logs/gdrive-mount.log";
        EnvironmentVariables = {
          HOME = home;
          PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
      };
    };
  };
}
