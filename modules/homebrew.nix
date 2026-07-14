{ config, pkgs, ... }:

let
  netbirdRcFormula = pkgs.writeText "netbird.rb" ''
    class Netbird < Formula
      desc "NetBird client"
      homepage "https://netbird.io/"
      version "0.75.0-rc.6"
      license "BSD-3-Clause"

      on_macos do
        if Hardware::CPU.arm?
          url "https://github.com/netbirdio/netbird/releases/download/v#{version}/netbird_#{version}_darwin_arm64.tar.gz"
          sha256 "6a7e9bfeb28f053087b7857f128032cc8e298b4f13d01397f790209de8fd63a9"
        end

        if Hardware::CPU.intel?
          url "https://github.com/netbirdio/netbird/releases/download/v#{version}/netbird_#{version}_darwin_amd64.tar.gz"
          sha256 "a6df4c1f1fe3c58c7b586787918c0d8506feb9206cc96b601fec9a46feb31a97"
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
      version "0.75.0-rc.6"
      sha256 "0fc493a22b46757c87f98895ce60baba85eac4edf45f935f265a66e11a27eebf"

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
