{ config, pkgs, ... }:

{
  imports = [
    ./aws.nix
    ./claude.nix
    ./clownops.nix
    ./fish.nix
    ./fonts.nix
    ./git.nix
    ./kube.nix
    ./nix-tools.nix
    ./obs.nix
    ./omniwm.nix
    ./orcaslicer.nix
    ./sops.nix
    ./ssh.nix
    ./television.nix
    ./uv.nix
    ./zed.nix
  ];

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.bun/bin"
  ];

  home.packages = [
    (pkgs.writeScriptBin "openhuman-sync" (builtins.readFile ./openhuman-sync.sh))
  ];

  home.stateVersion = "26.11";
}
