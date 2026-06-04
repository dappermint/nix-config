{ ... }:

{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
      extraFlags = [ "--force-cleanup" ];
    };

    taps = [
      "netbirdio/tap"
    ];

    brews = [
      "netbirdio/tap/netbird"
      "rustnet"
    ];

    casks = [
      "antigravity-cli"
      "aptakube"
      "arc"
      "claude"
      "claude-code@latest"
      "comet"
      "discord@ptb"
      "firefox@nightly"
      "mixxx"
      "netbirdio/tap/netbird-ui"
      "nordvpn"
      "orbstack"
      "orcaslicer"
      "orion"
      "osu"
      "qflipper"
      "signal@beta"
      "spotify"
      "steam"
      "telegram"
      "transmission"
      "warp"
      "zed"
      "zen"
    ];
  };
}
