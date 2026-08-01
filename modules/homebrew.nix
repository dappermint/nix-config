{ config, ... }:

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
      "apple/apple"
      "frankea/whisky"
      {
        name = "netbirdio/tap";
        trusted = true;
      }
    ];

    brews = [
      "awscli"
      "netbirdio/tap/netbird"
      "rustnet"
    ];

    casks = [
      "antigravity-cli"
      "anydesk"
      "aptakube"
      "atoll"
      "claude-code@latest"
      "claude-status-bar"
      "comet"
      "discord@canary"
      "figma"
      "firefox@nightly"
      "frankea/whisky/whisky"
      "freecad"
      "linear"
      "lm-studio"
      "netbirdio/tap/netbird-ui"
      "nordvpn"
      "obs"
      "orbstack"
      "orcaslicer"
      "osu"
      "pearcleaner"
      "rekordbox"
      "signal@beta"
      "spotify"
      "steam"
      "tailscale-app"
      "telegram"
      "telegram-desktop"
      "thebrowsercompany-dia"
      "tor-browser"
      "transmission"
      "utm"
      "warp@preview"
      "winbox"
      "zed"
      "zen"
      "zerotier-one"
    ];
  };

  system.activationScripts.extraActivation.text = ''
    # brew cleanup removes the imperative daemon during version bumps
    netbird="${config.homebrew.prefix}/bin/netbird"
    if [ -x "$netbird" ]; then
      if [ ! -f /Library/LaunchDaemons/netbird.plist ]; then
        "$netbird" service install
      fi
      if ! /bin/launchctl print system/netbird >/dev/null 2>&1; then
        /bin/launchctl bootstrap system /Library/LaunchDaemons/netbird.plist
      fi
      /bin/launchctl kickstart -k system/netbird
      /bin/launchctl print system/netbird >/dev/null
    fi
  '';
}
