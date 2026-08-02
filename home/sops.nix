{ config, ... }:

{
  # sops resolves its default key path through os.UserConfigDir, which on darwin
  # is ~/Library/Application Support, not ~/.config. point it at the real file
  # so the cli works without an explicit flag
  home.sessionVariables.SOPS_AGE_KEY_FILE = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
}
