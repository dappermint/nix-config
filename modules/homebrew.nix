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

  # netbird ships its own LaunchDaemon through `netbird service install`, and
  # `brew cleanup --prune=all` deletes it out from under launchd on every
  # version bump. nix-darwin cannot own the plist without fighting the brew
  # formula, so activation repairs it instead: install when the plist is gone,
  # bootstrap when launchd does not know it, and only restart when the binary
  # is actually newer than the running service
  system.activationScripts.extraActivation.text = ''
    netbird="${config.homebrew.prefix}/bin/netbird"
    netbird_plist=/Library/LaunchDaemons/netbird.plist
    netbird_stamp=/var/lib/nix-darwin/netbird-binary

    if [ -x "$netbird" ]; then
      if [ ! -f "$netbird_plist" ]; then
        echo "netbird: launchdaemon missing, reinstalling"
        "$netbird" service install
      fi

      if ! /bin/launchctl print system/netbird >/dev/null 2>&1; then
        echo "netbird: not loaded, bootstrapping"
        /bin/launchctl bootstrap system "$netbird_plist"
      fi

      install -d "$(dirname "$netbird_stamp")"
      current=$(/usr/bin/shasum -a 256 "$netbird" | /usr/bin/awk '{print $1}')
      if [ "$current" != "$(cat "$netbird_stamp" 2>/dev/null || true)" ]; then
        echo "netbird: binary changed, restarting service"
        /bin/launchctl kickstart -k system/netbird
        printf '%s\n' "$current" > "$netbird_stamp"
      fi

      /bin/launchctl print system/netbird >/dev/null
    fi
  '';
}
