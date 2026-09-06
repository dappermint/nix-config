{
  config,
  pkgs,
  ...
}:

let
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;
  mountPoint = "${home}/GoogleDrive";

  mountScript = pkgs.writeShellScriptBin "gdrive-mount" ''
    set -euo pipefail
    # make sure mount directory exists
    mkdir -p "${mountPoint}"

    # if already mounted, exit gracefully
    if /sbin/mount | grep -q "${mountPoint}"; then
      echo "Google Drive is already mounted at ${mountPoint}"
      exit 0
    fi

    echo "Mounting Google Drive to ${mountPoint} via rclone nfsmount..."
    exec ${pkgs.rclone}/bin/rclone nfsmount gdrive: "${mountPoint}" \
      --config "${config.sops.templates."rclone.conf".path}" \
      --vfs-cache-mode full \
      --vfs-cache-max-size 10G \
      --vfs-cache-max-age 24h \
      --dir-cache-time 15m \
      --noappledouble \
      --volname "Google Drive"
  '';

  unmountScript = pkgs.writeShellScriptBin "gdrive-umount" ''
    set -euo pipefail
    if /sbin/mount | grep -q "${mountPoint}"; then
      echo "Unmounting ${mountPoint}..."
      /sbin/umount "${mountPoint}"
    else
      echo "${mountPoint} is not mounted."
    fi
  '';
in
{
  # install the CLI control scripts
  environment.systemPackages = [
    mountScript
    unmountScript
  ];

  # launchagent to keep it mounted automatically in user session
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
