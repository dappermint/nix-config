final: _prev: {
  google-sans-flex = final.callPackage ../packages/google-sans-flex { };
  hey-cli = final.callPackage ../packages/hey-cli { };
  mkspiFirmware = final.callPackage ../packages/mkspi-firmware { };
  rsreticulum = final.callPackage ../packages/rsreticulum { };
  omniwm = _prev.omniwm.overrideAttrs (_: rec {
    version = "0.7.5";
    src = final.fetchurl {
      url = "https://github.com/OmniNull/OmniWM/releases/download/v${version}/OmniWM-v${version}.zip";
      hash = "sha256-oV/KNBGojdBviTUyjChiY9V6RMe8wiVUd+KTA/qUzM4=";
    };
  });

  # matter.js resolves a node's A/AAAA by the service instance name instead of
  # the SRV target host, so wifi/ip commissioning stalls forever at 18.1
  # Reconnect with "Resolving (no address known)". upstream fix landed the day
  # 1.4.0 was tagged and missed the release: matter-js/matter.js@71d2ccec.
  # patched as a copy of the cached upstream output rather than overrideAttrs:
  # the npm rebuild would not fit in mkspi's ram and the mac cannot build
  # aarch64-linux
  matterjs-server =
    final.runCommand "matterjs-server-${_prev.matterjs-server.version}"
      {
        inherit (_prev.matterjs-server) meta;
        src = _prev.matterjs-server;
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
