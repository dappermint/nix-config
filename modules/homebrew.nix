{ config, pkgs, ... }:

let
  netbirdRcFormula = pkgs.writeText "netbird.rb" ''
    class Netbird < Formula
      desc "NetBird client"
      homepage "https://netbird.io/"
      version "0.75.0-rc.5"
      license "BSD-3-Clause"

      on_macos do
        if Hardware::CPU.arm?
          url "https://github.com/netbirdio/netbird/releases/download/v#{version}/netbird_#{version}_darwin_arm64.tar.gz"
          sha256 "b22242e73b00c7139049116a8000d453d2ac508b94ca77efa08189494c67e3f8"
        end

        if Hardware::CPU.intel?
          url "https://github.com/netbirdio/netbird/releases/download/v#{version}/netbird_#{version}_darwin_amd64.tar.gz"
          sha256 "60a106bc3abc31530e58552173bd9d84070a4bd562801c90e36e3ad0c046cc66"
        end
      end

      def install
        bin.install "netbird"
      end

      test do
        system "#{bin}/netbird", "version"
      end
    end
  '';

  netbirdUiRcCask = pkgs.writeText "netbird-ui-rc.rb" ''
    cask "netbird-ui-rc" do
      version "0.75.0-rc.5"
      sha256 "c4e519c69be6c951c7dceec18efd8217ad41553d12c37185bb17ce415ff96e74"

      url "https://github.com/netbirdio/netbird/releases/download/v#{version}/netbird_#{version}_darwin.pkg",
          verified: "github.com/netbirdio/netbird/"
      name "NetBird"
      desc "NetBird GUI Client RC"
      homepage "https://www.netbird.io/"

      installer script: {
        executable: "/bin/sh",
        args:       [
          "-c",
          "set -eu; tmpdir=$(mktemp -d); trap 'rm -rf \"$tmpdir\"' EXIT; pkgutil --expand '#{staged_path}/netbird_#{version}_darwin.pkg' \"$tmpdir/pkg\"; ditto -x -z \"$tmpdir/pkg/netbird.pkg/Payload\" \"$tmpdir/payload\"; rm -rf /Applications/NetBird.app; ditto \"$tmpdir/payload/Applications/NetBird.app\" /Applications/NetBird.app",
        ],
        sudo:       true,
      }

      uninstall quit:   "io.netbird.client",
                delete: "/Applications/NetBird.app"

      zap trash: [
        "~/Library/Application Support/NetBird",
        "~/Library/Caches/io.netbird.client",
        "~/Library/HTTPStorages/io.netbird.client",
        "~/Library/Preferences/io.netbird.client.plist",
        "~/Library/Saved Application State/io.netbird.client.savedState",
      ]
    end
  '';
in
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
      {
        name = "dappy/netbird-rc";
        trusted = true;
      }
    ];

    brews = [
      "dappy/netbird-rc/netbird"
      "rustnet"
    ];

    casks = [
      "antigravity-cli"
      "aptakube"
      "atoll"
      "anydesk"
      "claude-code@latest"
      "comet"
      "dappy/netbird-rc/netbird-ui-rc"
      "discord@ptb"
      "figma"
      "firefox@nightly"
      "freecad"
      "linear"
      "nordvpn"
      "orbstack"
      "orcaslicer"
      "osu"
      "pearcleaner"
      "rekordbox"
      "signal@beta"
      "spotify"
      "steam"
      "telegram"
      "thebrowsercompany-dia"
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
    netbirdTap="${config.homebrew.prefix}/Library/Taps/dappy/homebrew-netbird-rc"
    install -d "$netbirdTap/Formula"
    install -d "$netbirdTap/Casks"
    install -m 0644 ${netbirdRcFormula} "$netbirdTap/Formula/netbird.rb"
    install -m 0644 ${netbirdUiRcCask} "$netbirdTap/Casks/netbird-ui-rc.rb"
  '';
}
