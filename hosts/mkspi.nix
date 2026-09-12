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
  imports = [ inputs.sops-nix.nixosModules.sops ];

  nixpkgs.hostPlatform = "aarch64-linux";
  nixpkgs.overlays = [ (import ../overlays) ];

  networking.hostName = "mkspi";
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

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  sops = {
    defaultSopsFile = "${self}/secrets/mkspi.yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.garage_backup_env = { };
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

  # Daily snapshot backup of Home Assistant to Garage S3 over Tailscale
  systemd.services.home-assistant-backup = {
    description = "Backup Home Assistant config to Garage S3";
    path = with pkgs; [
      awscli2
      gnutar
      zstd
    ];
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
        tar --exclude='*.db-wal' --exclude='*.db-shm' --exclude='home-assistant.log*' -cf - -C /var/lib hass | zstd -3 -o "''${ARCHIVE}"
        aws --endpoint-url http://100.80.221.44:3900 s3 cp "''${ARCHIVE}" "s3://homeassistant-backups/ha_backup_''${TS}.tar.zst"
        rm -f "''${ARCHIVE}"
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

  services.nginx.virtualHosts."esphome.dappy.lgbt" = {
    useACMEHost = "home.dappy.lgbt";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:6052";
      proxyWebsockets = true;
    };
  };

  services.home-assistant = {
    enable = true;
    package =
      (pkgs.home-assistant.override {
        extraPackages =
          ps: with ps; [
            aioesphomeapi
            bthome-ble
            gtts
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
      "met"
      "wyoming"
      "xiaomi_ble"
      "xiaomi_miio"
    ];
    config = null;
    themes = [ pkgs.home-assistant-themes.material-you-theme ];
  };

  services.wyoming.piper.servers."en-gb" = {
    enable = true;
    voice = "en_GB-cori-high";
    uri = "tcp://127.0.0.1:10200";
  };

  services.tailscale.enable = true;

  security.acme = {
    acceptTerms = true;
    defaults.email = "dappy@hey.com";
    certs."home.dappy.lgbt" = {
      dnsProvider = "cloudflare";
      environmentFile = "/var/lib/acme/cf-token";
      group = "nginx";
      extraDomainNames = [ "esphome.dappy.lgbt" ];
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
  };

  networking.firewall = {
    allowedTCPPorts = [
      80
      443
      8123
    ];
    trustedInterfaces = [ "tailscale0" ];
  };

  # 1gb of ddr3: zstd zram at 150% with high swappiness keeps ram footprint small
  # and prevents micro-sd wear from swap thrashing
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 150;
  };

  documentation.enable = false;
  documentation.nixos.enable = false;

  nix.settings = {
    experimental-features = [
      "flakes"
      "nix-command"
    ];
    auto-optimise-store = true;
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
