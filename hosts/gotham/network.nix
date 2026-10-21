{ config, lib, ... }:

{
  # matter-over-wifi devices live on the isolated smart home vlan, so the
  # controller needs a leg there for the operational CASE session. no
  # --primary-interface: pinning one makes matter.js stop sending mdns queries
  # entirely on a vlan sub-interface (0 packets on the wire), while unpinned it
  # scans every interface and the router's mdns repeater delivers the answers
  # the rk3328 gmac has no mac address in efuse, so the kernel rolls a random one
  # every boot and the dhcp lease (and home.dappy.lgbt with it) moves
  networking.interfaces.eth0.macAddress = "f2:09:92:be:c2:c7";

  networking.vlans.eth0-8 = {
    id = 8;
    interface = "eth0";
  };

  networking.interfaces.eth0-8.useDHCP = true;

  networking.dhcpcd.extraConfig = ''
    interface eth0-8
    nogateway
    interface wlu1
    nogateway
  '';

  networking.wireless = {
    enable = true;
    interfaces = [ "wlu1" ];
    secretsFile = config.sops.secrets.wifi_env.path;
    networks."tel aviv".pskRaw = "ext:psk_telaviv";
  };

  services.tailscale.enable = true;

  # conway joins only so its honcho can reach 9r.dappy.lgbt; the netbird acl
  # lets k8s in on tcp 443 and nothing out, so no dns or routes from it here
  services.netbird.clients.conway = {
    port = 51820;
    login = {
      enable = true;
      setupKeyFile = config.sops.secrets.netbird_setup_key.path;
    };
    environment = {
      NB_MANAGEMENT_URL = "https://netbird.clownway.org:33073";
      NB_DISABLE_DNS = "true";
      NB_DISABLE_CLIENT_ROUTES = "true";
    };
  };

  services.zerotierone = {
    enable = true;
    joinNetworks = [ "f3797ba7a813d7ad" ];
  };

  services.blocky = {
    enable = true;
    settings = {
      ports.dns = 53;
      # split-horizon: the *.dappy.lgbt names live on the zt overlay, not the
      # lan, so zt clients (and the mac when off-lan) resolve them to the zt ip
      customDNS.mapping =
        let
          cert = config.security.acme.certs."home.dappy.lgbt";
        in
        lib.genAttrs ([ cert.domain ] ++ cert.extraDomainNames) (_: "10.212.240.225");
      upstreams.groups.default = [
        "https://dns.nextdns.io/848374"
        "9.9.9.9"
      ];
      caching = {
        minTime = "5m";
        prefetching = true;
      };
    };
  };

  # reticulum AutoInterface: multicast discovery, unicast reverse peering and
  # unicast data. the module's openMulticastPorts opens 27916 (a typo for 29716)
  # and only multicast 42671, so peers are found but their data is dropped
  networking.firewall.interfaces.eth0.allowedUDPPorts = [
    29716
    29717
    42671
    # syncthing: local discovery and quic
    21027
    22000
  ];

  networking.firewall.interfaces.eth0.allowedTCPPorts = [ 22000 ];

  # home assistant and esphome are reachable through nginx on 443 only: opening
  # 8123 would hand out a plaintext bypass of the tls the acme cert exists for.
  # tailscale0 is trusted, so direct access still works over the tailnet
  # mdns is multicast, and the nixos firewall drops every non-unicast packet by
  # default. without this the matter controller sends queries fine but never
  # receives an answer, so commissioning stalls at 18.1 Reconnect forever.
  # matter itself needs nothing: the controller dials out from an ephemeral port
  networking.firewall = {
    allowedTCPPorts = [
      80
      443
      53
    ];
    allowedUDPPorts = [
      53
      5353
    ];
    trustedInterfaces = [ "tailscale0" ];
    # chromecast fetches tts audio over plain http from internal_url and cannot
    # be pointed at 443: it refuses the lan-only hostname. scoping 8123 to the
    # wired lan keeps the plaintext port off every other interface
    extraCommands = ''
      iptables -I nixos-fw 4 -p tcp --dport 8123 -s 10.14.88.0/24 -j nixos-fw-accept
    '';
    extraStopCommands = ''
      iptables -D nixos-fw -p tcp --dport 8123 -s 10.14.88.0/24 -j nixos-fw-accept || true
    '';
  };
}
