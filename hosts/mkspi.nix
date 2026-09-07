{

  lib,
  pkgs,
  ...
}:

let
  user = "dappy";
  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN7KvZLKybxYKt5Vu5UPcQ4zxIq+FPRyAKQgnvOpzy6Z";
in
{
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

  users.users.root.openssh.authorizedKeys.keys = [ sshKey ];
  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ sshKey ];
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

  services.tailscale.enable = true;

  networking.firewall = {
    allowedTCPPorts = [ 8123 ];
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
