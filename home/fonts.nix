{ lib, ... }:

let
  fonts = import ../lib/fonts.nix;
in
{
  home.activation.fontDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run /usr/bin/defaults write NSGlobalDomain NSFixedPitchFont -string "${fonts.monoPostScriptName}"
    run /usr/bin/defaults write dev.warp.Warp-Preview FontName -string '"${fonts.monoFamily}"'
  '';
}
