{ config, pkgs, ... }:

{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      libusb1
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
      }/bin/python3 ${../gotham-waves.py}";
      Restart = "always";
      DynamicUser = true;
      SupplementaryGroups = [ "dialout" ];
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

  # abode talks matter itself now (/var/lib/hass/matter/controller.bin);
  # matterjs stays declared so rollback is flipping this and deleting that file.
  # its state in /var/lib/private/matterjs-server still holds the old fabric.
  services.matterjs-server = {
    enable = false;
    extraArgs = [ "--ble-proxy" ];
  };
}
