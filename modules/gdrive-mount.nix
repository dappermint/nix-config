{
  config,
  pkgs,
  ...
}:

let
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;
  mountPoint = "${home}/GoogleDrive";

  mountScript = pkgs.writeShellApplication {
    name = "gdrive-mount";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.rclone
    ];
    text = ''
      mkdir -p "${mountPoint}"

      if /sbin/mount | grep -q "${mountPoint}"; then
        echo "Google Drive is already mounted at ${mountPoint}"
        exit 0
      fi

      echo "Mounting Google Drive to ${mountPoint} via rclone nfsmount..."
      exec rclone nfsmount gdrive: "${mountPoint}" \
        --config "${config.sops.templates."rclone.conf".path}" \
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
  environment.systemPackages = [
    mountScript
    unmountScript
  ];

  launchd.user.agents.gdrive-mount = {
    serviceConfig = {
      Label = "org.${user}.gdrive-mount";
      ProgramArguments = [ "${mountScript}/bin/gdrive-mount" ];
      RunAtLoad = true;
      KeepAlive = {
        SuccessfulExit = false;
        NetworkState = true;
      };
      ProcessType = "Background";
      StandardOutPath = "${home}/Library/Logs/gdrive-mount.log";
      StandardErrorPath = "${home}/Library/Logs/gdrive-mount.log";
      EnvironmentVariables = {
        HOME = home;
        PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };
}
