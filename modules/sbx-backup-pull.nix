{
  config,
  lib,
  pkgs,
  ...
}:

# sbx-intelmac has no route out of the space, so the mac pulls. the source is a
# restic repo now, which is content-addressed and encrypted, so this mirrors it
# in place instead of keeping dated copies: restic's own retention is the
# history. this mirror IS the offsite copy of the hackerspace.
let
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;
  dest = "${home}/Documents/Projects/sbx/backups/intelmac";

  pull = pkgs.writeShellApplication {
    name = "sbx-backup-pull";
    runtimeInputs = [
      pkgs.rsync
      pkgs.openssh
      pkgs.coreutils
      pkgs.restic
    ];
    text = ''
      mkdir -p "${dest}/repo"
      rsync -a --delete --timeout=120 \
        -e "ssh -o BatchMode=yes -o ConnectTimeout=10" \
        dappy@10.212.240.196:/var/backup/sbx/repo/ "${dest}/repo/"

      # a mirror that does not verify is still a hypothesis
      RESTIC_PASSWORD_FILE="${home}/.config/sbx/restic-password" \
        restic -r "${dest}/repo" snapshots --compact --latest 3
    '';
  };
in
{
  options.services.sbx-backup-pull.enable = lib.mkEnableOption "the nightly sbx backup pull";

  config = lib.mkIf config.services.sbx-backup-pull.enable {
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
  };
}
