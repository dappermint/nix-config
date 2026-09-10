{ config, pkgs, ... }:

# pulls the nightly bundle sbx-intelmac writes to /var/backup/sbx (klipper
# state, moonraker history, authentik). the box has no route out of the space,
# so the mac fetches over zerotier. keeps 30 dated copies
let
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;
  dest = "${home}/Documents/Werk/repos/personal/sbx/backups/intelmac";

  pull = pkgs.writeShellApplication {
    name = "sbx-backup-pull";
    runtimeInputs = [
      pkgs.rsync
      pkgs.openssh
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      day=$(date +%F)
      mkdir -p "${dest}/$day"
      rsync -a --timeout=60 -e "ssh -o BatchMode=yes -o ConnectTimeout=10" \
        dappy@10.212.240.196:/var/backup/sbx/ "${dest}/$day/"
      ln -sfn "$day" "${dest}/latest"
      find "${dest}" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} +
    '';
  };
in
{
  launchd.user.agents.sbx-backup-pull = {
    serviceConfig = {
      Label = "org.${user}.sbx-backup-pull";
      ProgramArguments = [ "${pull}/bin/sbx-backup-pull" ];
      StartCalendarInterval = {
        Hour = 9;
        Minute = 30;
      };
      Nice = 10;
      LowPriorityIO = true;
      ProcessType = "Background";
      StandardOutPath = "${home}/Library/Logs/sbx-backup-pull.log";
      StandardErrorPath = "${home}/Library/Logs/sbx-backup-pull.log";
      EnvironmentVariables.HOME = home;
    };
  };

  environment.systemPackages = [ pull ];
}
