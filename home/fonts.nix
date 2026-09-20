{ lib, pkgs, ... }:

let
  fonts = import ../lib/fonts.nix;
  zenProfile = "Library/Application Support/zen/Profiles/41icbwn0.Default (release)";
  zenPrefs =
    lib.concatMapStrings
      (l: ''
        user_pref("font.name.sans-serif.${l}", "${fonts.uiFamily}");
        user_pref("font.name.serif.${l}", "${fonts.uiFamily}");
        user_pref("font.name.monospace.${l}", "${fonts.monoFamily}");
      '')
      [
        "x-western"
        "x-cyrillic"
        "he"
      ];
in
{
  home.activation.fontDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run /usr/bin/defaults write NSGlobalDomain NSFixedPitchFont -string "${fonts.monoPostScriptName}"
    run /usr/bin/defaults write dev.warp.Warp-Preview FontName -string '"${fonts.monoFamily}"'
    run ${pkgs.yq-go}/bin/yq -i '.terminal.font_family = "${fonts.monoFamily}" | .desktop.font_family = "${fonts.uiFamily}"' "$HOME/.hermes/config.yaml"
    bruno="$HOME/Library/Application Support/bruno/preferences.json"
    if [ -f "$bruno" ]; then
      ${pkgs.jq}/bin/jq '.preferences.font.codeFont = "${fonts.monoFamily}"' "$bruno" > "$bruno.tmp" && run mv "$bruno.tmp" "$bruno"
    fi
    ws="$HOME/.config/wireshark/preferences"
    [ -f "$ws" ] && run ${pkgs.gnused}/bin/sed -i 's/^gui.qt.font_name: [^,]*/gui.qt.font_name: ${fonts.monoFamily}/' "$ws"
  '';

  xdg.configFile."ghostty/config".text = ''
    font-family = ${fonts.monoFamily}
  '';

  home.file."${zenProfile}/user.js".text = ''
    ${zenPrefs}
    user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
  '';
  home.file."${zenProfile}/chrome/userChrome.css".text = ''
    * { font-family: "${fonts.uiFamily}" !important; }
  '';
}
