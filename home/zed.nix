let
  fonts = import ../lib/fonts.nix;
in
{
  programs.zed-editor = {
    enable = true;
    package = null;
    userSettings = {
      ui_font_family = fonts.uiFamily;
      buffer_font_family = fonts.monoFamily;
      terminal.font_family = fonts.monoFamily;
      auto_install_extensions.nix = true;
      languages.Nix.language_servers = [
        "nixd"
        "!nil"
      ];
    };
  };
}
