{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.kanata;
  driverPkg = cfg.package.passthru.darwinDriver;
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

    # macos only activates driverkit extensions from apps in /Applications
    system.activationScripts.preActivation.text = ''
      rm -rf /Applications/.Karabiner-VirtualHIDDevice-Manager.app
      cp -R "${driverPkg}/Applications/.Karabiner-VirtualHIDDevice-Manager.app" /Applications/

      mkdir -p "/Library/Application Support/org.pqrs"
      rm -rf "/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice"
      cp -R "${driverPkg}/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice" "/Library/Application Support/org.pqrs/"
    '';

    system.activationScripts.postActivation.text = ''
      /Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager activate || true
    '';

    launchd.daemons.karabiner-vhid-daemon = {
      command = ''"/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"'';
      serviceConfig = {
        Label = "org.pqrs.Karabiner-VirtualHIDDevice-Daemon";
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Interactive";
        StandardOutPath = "/Library/Logs/karabiner-vhid-daemon.log";
        StandardErrorPath = "/Library/Logs/karabiner-vhid-daemon.err.log";
      };
    };

    # root, since the vhid daemon's socket is root-only
    launchd.daemons.kanata = {
      command = "${cfg.package}/bin/kanata -c ${configFile} --no-wait --release-grab-on-lock";
      serviceConfig = {
        Label = "org.kanata.kanata";
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Interactive";
        StandardOutPath = "/Library/Logs/kanata.log";
        StandardErrorPath = "/Library/Logs/kanata.err.log";
      };
    };
  };
}
