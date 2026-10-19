{ config, pkgs, ... }:

let
  devApp = "${config.home.homeDirectory}/Applications/OmniWM Dev.app";
in
{
  # stable dropped for the local dev build, which ships its own ctl matching its ipc
  home.packages = [
    (pkgs.writeShellScriptBin "omniwmctl" ''exec "${devApp}/Contents/MacOS/omniwmctl" "$@"'')
  ];

  home.sessionVariables.OMNIWM_SIGNING_IDENTITY = "Hermes Local Signing";

  launchd.agents.omniwm-dev = {
    enable = true;
    config = {
      ProgramArguments = [
        "/usr/bin/open"
        "-a"
        devApp
      ];
      RunAtLoad = true;
    };
  };
}
