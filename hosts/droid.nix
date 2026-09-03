{ pkgs, ... }:

let
  groups = import ../lib/packages.nix { inherit pkgs; };
in
{
  imports = [ ../home/droid.nix ];

  home.username = "droid";
  home.homeDirectory = "/home/droid";

  # standalone home-manager, so the cli has to come from the configuration
  # itself: nix-switch calls it and there is no system generation providing it
  programs.home-manager.enable = true;

  # editors is omitted: home/neovim.nix installs and configures neovim, and
  # taking the group as well would put a second, unconfigured copy on PATH
  home.packages = groups.shell ++ groups.vcs ++ groups.nixTooling;
}
