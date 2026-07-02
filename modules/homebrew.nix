{ config, pkgs, ... }:

let
  netbirdRcFormula = pkgs.writeText "netbird.rb" ''
    class Netbird < Formula
      desc "NetBird client"
      homepage "https://netbird.io/"
      version "0.75.0-rc.4"
      license "BSD-3-Clause"

      on_macos do
        if Hardware::CPU.arm?
          url "https://github.com/netbirdio/netbird/releases/download/v#{version}/netbird_#{version}_darwin_arm64.tar.gz"
          sha256 "4c9e483584271220db366be1cea3835f714504dde88c2c279b6a70584bf38a68"
        end

        if Hardware::CPU.intel?
          url "https://github.com/netbirdio/netbird/releases/download/v#{version}/netbird_#{version}_darwin_amd64.tar.gz"
          sha256 "3d0874fc3fdfef68a16e16af193c90447e9863e0cb9abe0006daec3c4ba3aa54"
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
      version "0.75.0-rc.4"
      sha256 "b079d4e728b95948ae8fdba4bf58f627f6062939b749c333f7c5910bdf14e71d"

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
      "atoll"
      "antigravity-cli"
      "aptakube"
      "claude-code@latest"
      "comet"
      "thebrowsercompany-dia"
      "discord@ptb"
      "firefox@nightly"
      "mixxx"
      "dappy/netbird-rc/netbird-ui-rc"
      "nordvpn"
      "pearcleaner"
      "linear"
      "orbstack"
      "orcaslicer"
      "osu"
      "signal@beta"
      "spotify"
      "steam"
      "telegram"
      "transmission"
      "utm"
      "warp@preview"
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
