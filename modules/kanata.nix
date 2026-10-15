{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.kanata;
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;

  configFile = pkgs.writeText "kanata.kbd" cfg.config;
in
{
  options.services.kanata = {
    enable = lib.mkEnableOption "kanata software keyboard remapper";
    package = lib.mkPackageOption pkgs "kanata" { };
    config = lib.mkOption {
      type = lib.types.lines;
      default = ''
        (defcfg
          process-unmapped-keys yes
        )

        (defsrc
          caps
        )

        (defalias
          caps-hyper (tap-hold-press 200 200 esc (multi lctl lalt lmet))
        )

        (deflayer base
          @caps-hyper
        )
      '';
      description = "kanata .kbd configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    launchd.user.agents.kanata = {
      serviceConfig = {
        Label = "org.${user}.kanata";
        ProgramArguments = [
          "${cfg.package}/bin/kanata"
          "-c"
          "${configFile}"
          "--no-wait"
          "--release-grab-on-lock"
        ];
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Interactive";
        StandardOutPath = "${home}/Library/Logs/kanata.log";
        StandardErrorPath = "${home}/Library/Logs/kanata.err.log";
        EnvironmentVariables.HOME = home;
      };
    };
  };
}
