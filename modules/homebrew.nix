{ ... }:

{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
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
      "mixxx"
      "netbirdio/tap/netbird-ui"
      "nordvpn"
      "orbstack"
      "orion"
      "osu"
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
