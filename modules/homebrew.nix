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
      # the PE half of the wine runtimes the self-hosted runners build. it has
      # to be this toolchain and not nixpkgs' mingw: nix's cc-wrapper needs a
      # NIX_LDFLAGS that only exists inside a nix build (without it every PE
      # link fails on -lmcfgthread), and nixpkgs builds mingw against
      # mcfgthread rather than the win32 threads the hosted runners use.
      # steam's CM login stall was traced to exactly this kind of PE toolchain
      # difference, so it stays identical to what the hosted runners have.
      "mingw-w64"
      "netbirdio/tap/netbird"
      "rustnet"
    ];

    casks = [
      "alt-tab"
      "antigravity-cli"
      "anydesk"
      "aptakube"
      "atoll"
      "bruno"
      "claude-code@latest"
      "claude-status-bar"
      "comet"
      "discord@canary"
      "figma"
      "firefox@nightly"
      "frankea/whisky/whisky"
      "freecad"
      "jordanbaird-ice"
      "linear"
      "lm-studio"
      "monitorcontrol"
      "netbirdio/tap/netbird-ui"
      "nordvpn"
      "obs"
      "orbstack"
      "orcaslicer"
      "osu"
      "pearcleaner"
      "raycast"
      "rekordbox"
      "shottr"
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
      "wireshark-app"
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
