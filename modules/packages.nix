{ pkgs, inputs, ... }:

let
  groups = import ../lib/packages.nix { inherit pkgs; };

  # hey-cli publishes darwin artifacts only, so it cannot live in lib/packages.nix
  # without breaking rubicon's eval
  macos = [
    pkgs.ardour
    pkgs.hey-cli
    pkgs.macmon
    inputs.ratatouille.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  toys = [
    inputs.tart.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.waves.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
in
{
  environment.systemPackages =
    groups.shell
    ++ groups.vcs
    ++ groups.editors
    ++ groups.agents
    ++ groups.languages
    ++ groups.infra
    ++ groups.kubernetes
    ++ groups.nixTooling
    ++ groups.fontTooling
    ++ groups.browsers
    ++ macos
    ++ toys;
}
