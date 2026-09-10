{ config, ... }:

let
  inherit (config.home) homeDirectory;

  repo = "${homeDirectory}/Documents/Werk/repos/personal/sbx/klipper-config/orcaslicer";
  orcaDir = "Library/Application Support/OrcaSlicer";

  # intelmac links each preset file from the store, which is fine on a host
  # nobody tunes from. here the presets get edited in the gui, so the links
  # point out of the store at the checkout: a save lands in the repo as a diff
  # instead of failing on a read-only symlink. whole directories, not files,
  # because the flake builds from the git ref and cannot enumerate a tree that
  # lives outside it, and because a preset added in the gui then needs no nix
  # edit to match.
  dirs = [
    "physical_printer"
    "user/default/filament"
    "user/default/machine"
    "user/default/process"
  ];
in
{
  home.file = builtins.listToAttrs (
    map (d: {
      name = "${orcaDir}/${d}";
      value.source = config.lib.file.mkOutOfStoreSymlink "${repo}/${d}";
    }) dirs
  );
}
