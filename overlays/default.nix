final: prev: {
  google-sans-flex = final.callPackage ../packages/google-sans-flex { };
  hey-cli = final.callPackage ../packages/hey-cli { };
  mkspiFirmware = final.callPackage ../packages/mkspi-firmware { };
  rsreticulum = final.callPackage ../packages/rsreticulum { };
  # nixpkgs trails npm; the lock is regenerated from the tarball's package.json
  # nixpkgs carries the package; this only keeps the user agent patch
  _9router = prev._9router.overrideAttrs (old: {
    postPatch = old.postPatch + ''
      # upstream only serves gemini-4-argon to the antigravity cli user agent
      sed -i -E 's#antigravity/ide/(\$\{[[:alnum:]_$]+\}|[0-9.]+) darwin/arm64#antigravity/cli/1.4.2 darwin/arm64#g' \
        app/.next-cli-build/server/chunks/*.js
      grep -q 'antigravity/cli/1.4.2' app/.next-cli-build/server/chunks/*.js
    '';
  });
  omniwm = prev.omniwm.overrideAttrs (
    finalAttrs: _: {
      version = "0.7.6";
      src = final.fetchurl {
        url = "https://github.com/OmniNull/OmniWM/releases/download/v${finalAttrs.version}/OmniWM-v${finalAttrs.version}.zip";
        hash = "sha256-7IxhRqbyGnnhxArHDWESF2K5PPU80wjmPrROis4g/Nw=";
      };
    }
  );

  # matter.js resolves a node's A/AAAA by the service instance name instead of
  # the SRV target host, so wifi/ip commissioning stalls forever at 18.1
  # Reconnect with "Resolving (no address known)". upstream fix landed the day
  # 1.4.0 was tagged and missed the release: matter-js/matter.js@71d2ccec.
  # patched as a copy of the cached upstream output rather than overrideAttrs:
  # the npm rebuild would not fit in mkspi's ram and the mac cannot build
  # aarch64-linux
  matterjs-server =
    final.runCommand "matterjs-server-${prev.matterjs-server.version}"
      {
        inherit (prev.matterjs-server) meta;
        src = prev.matterjs-server;
      }
      ''
        cp -r --no-preserve=mode $src $out
        for f in $out/lib/matterjs-server/node_modules/@matter/general/dist/{esm,cjs}/net/dns-sd/IpServiceResolution.js; do
          substituteInPlace "$f" \
            --replace-fail 'hosts.add(service.names.get(record.name));' \
                           'hosts.add(service.names.get(record.value.target));'
        done
        substituteInPlace $out/bin/matterjs-server --replace-fail "$src" "$out"
        chmod +x $out/bin/matterjs-server
      '';
}
