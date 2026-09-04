{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

let
  user = "dappy";
in
{
  imports = [ "${modulesPath}/installer/sd-card/sd-image.nix" ];

  nixpkgs.hostPlatform = "aarch64-linux";
  nixpkgs.overlays = [ (import ../overlays) ];

  networking.hostName = "mkspi";
  system.stateVersion = "26.11";

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.kernelParams = [ "console=ttyS2,1500000n8" ];

  hardware.deviceTree.name = "rockchip/rk3328-roc-cc.dtb";

  # the fat partition only exists for the raspberry pi firmware, and rockchip
  # wants the bootloader in the gap in front of it instead: idbloader, atf and
  # u-boot in one blob at sector 64
  sdImage = {
    compressImage = false;
    firmwareSize = 16;
    populateFirmwareCommands = "";
    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';
    postBuildCommands = ''
      dd if=${pkgs.ubootMksPi}/u-boot-rockchip.bin of=$img seek=64 conv=notrunc
    '';
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN7KvZLKybxYKt5Vu5UPcQ4zxIq+FPRyAKQgnvOpzy6Z"
    ];
  };

  services.home-assistant = {
    enable = true;
    extraComponents = [
      "default_config"
      "esphome"
      "met"
    ];
    config.default_config = { };
  };

  networking.firewall.allowedTCPPorts = [ 8123 ];

  # 1gb of ddr3 and a python service that wants half of it, so the swap has to
  # come from somewhere that is not the sd card
  zramSwap = {
    enable = true;
    memoryPercent = 50;
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
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  security.sudo.wheelNeedsPassword = lib.mkDefault false;
}
