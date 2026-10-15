{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:

let
  user = "dappy";
  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN7KvZLKybxYKt5Vu5UPcQ4zxIq+FPRyAKQgnvOpzy6Z";
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.abode.nixosModules.default
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  nixpkgs.overlays = [ (import ../overlays) ];

  networking.hostName = "gotham";

  system.stateVersion = "26.11";

  # lustrated over armbian: its u-boot stays in the sd card gap (sector 64)
  # and reads extlinux.conf from the fat partition
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/e1d0f926-4f56-485e-acbd-2b1ed387b6bf";
    fsType = "ext4";
    options = [
      "noatime"
      "commit=60"
    ];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/9BA7-2596";
    fsType = "vfat";
    options = [ "noatime" ];
  };

  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "50%";

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  # a kernel+initrd pair is ~90 MB and /boot is a 256 MB vfat: current plus one
  # rollback. the builder copies before it prunes, so a deploy that changes the
  # kernel needs the rollback dropped first (rerun the extlinux builder, -g 1)
  boot.loader.generic-extlinux-compatible.configurationLimit = 2;
  boot.kernelParams = [ "console=ttyS2,1500000n8" ];
  boot.initrd.availableKernelModules = [
    "dw_mmc_rockchip"
    "mmc_block"
  ];

  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };

  hardware.deviceTree = {
    dtbSource = pkgs.mkspiFirmware;
    name = "rockchip/rk3328-mkspi.dtb";
  };
  hardware.firmware = [
    pkgs.mkspiFirmware
    pkgs.wireless-regdb
  ];

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  sops = {
    defaultSopsFile = "${self}/secrets/gotham.yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.garage_backup_env = { };
    secrets.kanidm_idm_admin_password.owner = "kanidm";
    secrets.kanidm_vaultwarden_secret.owner = "kanidm";
    secrets.kanidm_gatus_secret.owner = "kanidm";
    secrets.syncthing_gui_password.owner = "syncthing";
    secrets.wifi_env.owner = "wpa_supplicant";
    secrets.ninerouter_env = { };
    # the client side reads the same secret, but only as an env var
    templates."vaultwarden.env".content = ''
      SSO_CLIENT_SECRET=${config.sops.placeholder.kanidm_vaultwarden_secret}
    '';
    templates."gatus.env".content = ''
      GATUS_OIDC_SECRET=${config.sops.placeholder.kanidm_gatus_secret}
    '';
  };

  users.users.root.openssh.authorizedKeys.keys = [ sshKey ];
  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ sshKey ];
  };

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      libusb1
      zlib
      ncurses
    ];
  };

  systemd.services.esphome = {
    description = "ESPHome Device Builder Dashboard";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment = {
      NIX_LD = "/run/current-system/sw/share/nix-ld/lib/ld.so";
      NIX_LD_LIBRARY_PATH = "/run/current-system/sw/share/nix-ld/lib";
    };
    path = [ pkgs.git ];
    serviceConfig = {
      ExecStart = "${pkgs.esphome-device-builder}/bin/esphome-device-builder --host 127.0.0.1 --port 6052 /var/lib/esphome";
      Restart = "always";
      User = "root";
      WorkingDirectory = "/var/lib/esphome";
      StateDirectory = "esphome";
    };
  };

  # live 2.4 GHz spectrum from the esp-sdr c6, served at waves.petahtikva.lan
  systemd.services.waves = {
    description = "esp-sdr spectrum bridge";
    wantedBy = [ "multi-user.target" ];
    environment.WAVES_DEVICE = "/dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_8C:FD:49:1A:05:48-if00";
    serviceConfig = {
      ExecStart = "${
        pkgs.python3.withPackages (p: [
          p.numpy
          p.pyserial
        ])
      }/bin/python3 ${./gotham-waves.py}";
      Restart = "always";
      DynamicUser = true;
      SupplementaryGroups = [ "dialout" ];
    };
  };

  systemd.services.ninerouter = {
    description = "9router llm proxy";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs._9router}/bin/9router -n -t --skip-update --host 127.0.0.1";
      Restart = "always";
      EnvironmentFile = config.sops.secrets.ninerouter_env.path;
      User = "dappy";
      Group = "users";
      StateDirectory = "ninerouter";
      WorkingDirectory = "/var/lib/ninerouter";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
    environment = {
      HOME = "/var/lib/ninerouter";
      XDG_DATA_HOME = "/var/lib/ninerouter";
      XDG_CONFIG_HOME = "/var/lib/ninerouter";
    };
  };

  # abode replaces home assistant in place: same /var/lib/hass, port 8123
  # and hass user. rollback is flipping these two enables and switching
  services.abode.enable = true;

  systemd.services.home-assistant-backup = {
    description = "Backup Home Assistant config to Garage S3";
    path = with pkgs; [
      awscli2
      gnutar
      zstd
    ];
    # garage rejects CreateMultipartUpload carrying aws-cli 2.3x's default crc32
    # checksum ("invalid checksum algorithm"), so every archive past the 8 MB
    # multipart threshold failed. not a secret, unlike the credentials below
    environment = {
      AWS_REQUEST_CHECKSUM_CALCULATION = "when_required";
      AWS_RESPONSE_CHECKSUM_VALIDATION = "when_required";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      # the credentials are read by pid 1 at start time. an `environment` block
      # would render them into the unit file under /nix/store, which is
      # world-readable
      EnvironmentFile = config.sops.secrets.garage_backup_env.path;
      ExecStart = pkgs.writeShellScript "ha-backup" ''
        set -euo pipefail
        TS=$(date +%Y%m%d_%H%M%S)
        ARCHIVE="/tmp/ha_backup_''${TS}.tar.zst"
        trap 'rm -f "''${ARCHIVE}"' EXIT
        # vaultwarden and kanidm come from their own nightly snapshots, not the
        # live dirs: both hold sqlite dbs that tar would copy mid-write
        tar --exclude='*.db-wal' --exclude='*.db-shm' --exclude='home-assistant.log*' -cf - -C /var/lib hass -C /var/backup vaultwarden kanidm | zstd -3 -o "''${ARCHIVE}"
        aws --endpoint-url http://100.80.221.44:3900 s3 cp "''${ARCHIVE}" "s3://homeassistant-backups/ha_backup_''${TS}.tar.zst"
      '';
    };
  };

  systemd.timers.home-assistant-backup = {
    description = "Daily timer for Home Assistant Garage backup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
    };
  };

  services.home-assistant = {
    enable = false;
    package =
      (pkgs.home-assistant.override {
        extraPackages =
          ps: with ps; [
            aioesphomeapi
            bthome-ble
            gtts
            ibeacon-ble
            pychromecast
            python-miio
            xiaomi-ble
          ];
      }).overrideAttrs
        (old: {
          doInstallCheck = false;
          # xiaomi_ble has no description for STABILIZED, so scale updates raise
          # KeyError and no mass sensors are ever created
          postPatch = (old.postPatch or "") + ''
                    substituteInPlace homeassistant/components/xiaomi_ble/binary_sensor.py \
                      --replace-fail \
                        "    ExtendedBinarySensorDeviceClass.TOOTHBRUSH: BinarySensorEntityDescription(" \
                        "    ExtendedBinarySensorDeviceClass.STABILIZED: BinarySensorEntityDescription(
                key=ExtendedBinarySensorDeviceClass.STABILIZED,
                icon=\"mdi:scale-bathroom\",
            ),
            ExtendedBinarySensorDeviceClass.TOOTHBRUSH: BinarySensorEntityDescription("
          '';
        });
    extraComponents = [
      "bluetooth"
      "bthome"
      "cast"
      "default_config"
      "esphome"
      "google_translate"
      "ibeacon"
      "matter"
      "met"
      "otbr"
      "thread"
      "xiaomi_ble"
      "xiaomi_miio"
    ];
    config = null;
    themes = [ pkgs.home-assistant-themes.material-you-theme ];
  };

  # the c6 runs esp-sdr now (systemd.services.waves), so the KISS radio is off. to go
  # back, re-flash rnode154 and re-enable interfaces.radio
  services.rnsd = {
    enable = true;
    package = pkgs.rsreticulum;
    packageBinaryName = "rnsd-rs";
    extraGroups = [ "dialout" ];
    settings = {
      reticulum = {
        enable_transport = true;
        share_instance = true;
        respond_to_probes = true;
      };
      # eth0 only: eth0-8 is the isolated smart home leg, and AutoInterface on
      # both would bridge the two bridges at the reticulum layer
      interfaces.lan = {
        type = "AutoInterface";
        enabled = true;
        devices = "eth0";
      };
      interfaces.radio = {
        type = "KISSInterface";
        enabled = false;
        port = "/dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_8C:FD:49:1A:05:48-if00";
        speed = 115200;
      };
    };
  };

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

  # abode talks matter itself now (/var/lib/hass/matter/controller.bin);
  # matterjs stays declared so rollback is flipping this and deleting that file.
  # its state in /var/lib/private/matterjs-server still holds the old fabric.
  services.matterjs-server = {
    enable = false;
    extraArgs = [ "--ble-proxy" ];
  };

  networking.wireless = {
    enable = true;
    interfaces = [ "wlu1" ];
    secretsFile = config.sops.secrets.wifi_env.path;
    networks."tel aviv".pskRaw = "ext:psk_telaviv";
  };

  services.tailscale.enable = true;

  services.zerotierone = {
    enable = true;
    joinNetworks = [ "f3797ba7a813d7ad" ];
  };

  # same setup as sbx-intelmac: kanidm behind nginx, provisioned from here
  services.kanidm = {
    server.enable = true;
    package = pkgs.kanidmWithSecretProvisioning_1_11;
    server.settings = {
      domain = "id.dappy.lgbt";
      origin = "https://id.dappy.lgbt";
      bindaddress = "127.0.0.1:8443";
      # only nginx talks to this listener, with verification off, so a renewed
      # cert that kanidm has not reloaded yet breaks nothing
      tls_chain = "/var/lib/acme/home.dappy.lgbt/fullchain.pem";
      tls_key = "/var/lib/acme/home.dappy.lgbt/key.pem";
      online_backup = {
        path = "/var/backup/kanidm";
        versions = 3;
      };
    };
    provision = {
      enable = true;
      instanceUrl = "https://127.0.0.1:8443";
      acceptInvalidCerts = true;
      idmAdminPasswordFile = config.sops.secrets.kanidm_idm_admin_password.path;
      groups.home_users = { };
      persons.dappy = {
        displayName = "Lia Yoffe";
        mailAddresses = [ "dappy@hey.com" ];
        groups = [ "home_users" ];
      };
      systems.oauth2.vaultwarden = {
        displayName = "vaultwarden";
        originUrl = "https://vault.dappy.lgbt/identity/connect/oidc-signin";
        originLanding = "https://vault.dappy.lgbt/";
        basicSecretFile = config.sops.secrets.kanidm_vaultwarden_secret.path;
        preferShortUsername = true;
        scopeMaps.home_users = [
          "openid"
          "profile"
          "email"
        ];
      };
      systems.oauth2.gatus = {
        displayName = "status";
        originUrl = "https://status.dappy.lgbt/authorization-code/callback";
        originLanding = "https://status.dappy.lgbt/";
        basicSecretFile = config.sops.secrets.kanidm_gatus_secret.path;
        # gatus 5.37 sends no code_verifier (security/oidc.go), so kanidm's
        # mandatory pkce would reject every login. confidential client + state
        allowInsecureClientDisablePkce = true;
        scopeMaps.home_users = [ "openid" ];
      };
    };
  };
  users.users.kanidm.extraGroups = [ "nginx" ];

  services.vaultwarden = {
    enable = true;
    # nightly sqlite .backup snapshot, picked up by the garage backup at 04:00
    backupDir = "/var/backup/vaultwarden";
    environmentFile = config.sops.templates."vaultwarden.env".path;
    config = {
      DOMAIN = "https://vault.dappy.lgbt";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      SIGNUPS_ALLOWED = false;
      SSO_ENABLED = true;
      SSO_ONLY = true;
      SSO_CLIENT_ID = "vaultwarden";
      SSO_AUTHORITY = "https://id.dappy.lgbt/oauth2/openid/vaultwarden";
    };
  };

  services.syncthing = {
    enable = true;
    guiPasswordFile = config.sops.secrets.syncthing_gui_password.path;
    # devices and folders get paired from the gui; the defaults would delete
    # them again on every restart
    overrideDevices = false;
    overrideFolders = false;
    settings.gui = {
      inherit user;
      # nginx forwards Host: sync.dappy.lgbt, which the gui's dns-rebinding
      # check rejects. the gui password is what guards it
      insecureSkipHostcheck = true;
    };
  };

  # runs outside conway on purpose, so it still sees conway going down
  services.gatus = {
    enable = true;
    environmentFile = config.sops.templates."gatus.env".path;
    settings = {
      web = {
        address = "127.0.0.1";
        port = 8080;
      };
      security.oidc = {
        issuer-url = "https://id.dappy.lgbt/oauth2/openid/gatus";
        redirect-url = "https://status.dappy.lgbt/authorization-code/callback";
        client-id = "gatus";
        client-secret = "\${GATUS_OIDC_SECRET}";
        scopes = [ "openid" ];
      };
      endpoints = [
        {
          name = "abode";
          group = "home";
          url = "https://home.dappy.lgbt/api/";
          # one cert covers every *.dappy.lgbt name here, so this also catches
          # a failed acme renewal
          conditions = [
            "[STATUS] == 200"
            "[CERTIFICATE_EXPIRATION] > 240h"
          ];
        }
        {
          name = "esphome";
          group = "home";
          url = "https://esphome.dappy.lgbt/";
          conditions = [ "[STATUS] == 200" ];
        }
        {
          name = "kanidm";
          group = "home";
          url = "https://id.dappy.lgbt/status";
          conditions = [ "[STATUS] == 200" ];
        }
        {
          name = "vaultwarden";
          group = "home";
          url = "https://vault.dappy.lgbt/alive";
          conditions = [ "[STATUS] == 200" ];
        }
        {
          name = "syncthing";
          group = "home";
          url = "https://sync.dappy.lgbt/rest/noauth/health";
          conditions = [ "[STATUS] == 200" ];
        }
        {
          name = "router";
          group = "home";
          url = "icmp://10.14.88.1";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "k8s api";
          group = "conway";
          url = "tcp://100.120.79.74:6443";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "garage s3";
          group = "conway";
          url = "tcp://100.80.221.44:3900";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "sandb0x.space";
          group = "sbx";
          url = "https://sandb0x.space";
          conditions = [ "[STATUS] == 200" ];
        }
      ];
    };
  };
  # both fetch oidc discovery from kanidm through nginx at startup
  systemd.services.gatus.after = [
    "kanidm.service"
    "nginx.service"
  ];
  systemd.services.vaultwarden.after = [
    "kanidm.service"
    "nginx.service"
  ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "dappy@hey.com";
    certs."home.dappy.lgbt" = {
      dnsProvider = "cloudflare";
      # the router answers *.dappy.lgbt from static records for split horizon,
      # so a propagation check through it never sees cloudflare's txt record
      dnsResolver = "1.1.1.1:53";
      environmentFile = "/var/lib/acme/cf-token";
      group = "nginx";
      extraDomainNames = [
        "esphome.dappy.lgbt"
        "id.dappy.lgbt"
        "vault.dappy.lgbt"
        "sync.dappy.lgbt"
        "status.dappy.lgbt"
        "bin.dappy.lgbt"
        "9r.dappy.lgbt"
      ];
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts."home.dappy.lgbt" = {
      useACMEHost = "home.dappy.lgbt";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8123";
        proxyWebsockets = true;
      };
    };
    virtualHosts."esphome.dappy.lgbt" = {
      useACMEHost = "home.dappy.lgbt";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:6052";
        proxyWebsockets = true;
      };
    };
    virtualHosts."id.dappy.lgbt" = {
      useACMEHost = "home.dappy.lgbt";
      forceSSL = true;
      locations."/".proxyPass = "https://127.0.0.1:8443";
    };
    virtualHosts."vault.dappy.lgbt" = {
      useACMEHost = "home.dappy.lgbt";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8222";
        proxyWebsockets = true;
      };
    };
    virtualHosts."sync.dappy.lgbt" = {
      useACMEHost = "home.dappy.lgbt";
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:8384";
    };
    virtualHosts."status.dappy.lgbt" = {
      useACMEHost = "home.dappy.lgbt";
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:8080";
    };
    virtualHosts."waves.petahtikva.lan".locations."/" = {
      proxyPass = "http://127.0.0.1:8090";
      extraConfig = "proxy_buffering off;";
    };

    virtualHosts."bin.dappy.lgbt" = {
      useACMEHost = "home.dappy.lgbt";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8082";
        proxyWebsockets = true;
      };
    };
    virtualHosts."9r.dappy.lgbt" = {
      useACMEHost = "home.dappy.lgbt";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:20128";
        proxyWebsockets = true;
      };
    };
  };

  services.microbin = {
    enable = true;
    settings = {
      MICROBIN_BIND = "127.0.0.1";
      MICROBIN_PORT = 8082;
      MICROBIN_PUBLIC_PATH = "https://bin.dappy.lgbt/";
      MICROBIN_READONLY = false;
      MICROBIN_QR = true;
      MICROBIN_ENABLE_BURN_AFTER = true;
      MICROBIN_DEFAULT_EXPIRY = "24h";
    };
  };

  services.blocky = {
    enable = true;
    settings = {
      ports.dns = 53;
      # split-horizon: the *.dappy.lgbt names live on the zt overlay, not the
      # lan, so zt clients (and the mac when off-lan) resolve them to the zt ip
      customDNS.mapping = {
        "9r.dappy.lgbt" = "10.212.240.225";
        "home.dappy.lgbt" = "10.212.240.225";
        "esphome.dappy.lgbt" = "10.212.240.225";
        "id.dappy.lgbt" = "10.212.240.225";
        "vault.dappy.lgbt" = "10.212.240.225";
        "sync.dappy.lgbt" = "10.212.240.225";
        "status.dappy.lgbt" = "10.212.240.225";
        "bin.dappy.lgbt" = "10.212.240.225";
      };
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

  # nothing opens its ports on eth0, so it is reachable over the tailnet only
  services.soft-serve = {
    enable = true;
    settings = {
      name = "gotham";
      anon-access = "no-access";
      allow-keyless = false;
      initial_admin_keys = [ sshKey ];
      ssh = {
        listen_addr = ":23231";
        # the short magicdns name, not the full tail*.ts.net one: it
        # resolves the same on the tailnet and keeps the tailnet id out of
        # a public repo
        public_url = "ssh://gotham:23231";
      };
      http = {
        listen_addr = "127.0.0.1:23232";
        public_url = "http://127.0.0.1:23232";
      };
      git.listen_addr = "127.0.0.1:9418";
      stats.listen_addr = "127.0.0.1:23233";
    };
  };
  # the module's ExecPaths points at repos/, which does not exist on first
  # start, so the mount namespace setup fails before soft-serve can create it
  systemd.services.soft-serve.serviceConfig.StateDirectory = lib.mkForce [
    "soft-serve"
    "soft-serve/repos"
  ];

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

  # 1gb of ddr3: zstd zram at 150% with high swappiness keeps ram footprint small
  # and prevents micro-sd wear from swap thrashing
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 150;
  };

  services.journald.settings.Journal.SystemMaxUse = "200M";

  documentation.enable = false;
  documentation.nixos.enable = false;

  nix.package = inputs.lix.packages.${pkgs.stdenv.hostPlatform.system}.default;

  nix.settings = {
    experimental-features = [
      "flakes"
      "nix-command"
    ];
    auto-optimise-store = true;
    extra-substituters = [ "https://cache.lix.systems" ];
    extra-trusted-public-keys = [
      "cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o="
    ];
    trusted-users = [ user ];
    max-jobs = 1;
    cores = 3;
  };

  systemd.services.nix-daemon.serviceConfig = {
    CPUWeight = 20;
    IOWeight = 20;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  security.sudo.wheelNeedsPassword = lib.mkDefault false;
}
