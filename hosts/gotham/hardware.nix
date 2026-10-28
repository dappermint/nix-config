{ pkgs, ... }:

{
  # lustrated over armbian: its u-boot stays in the sd card gap (sector 64)
  # and reads extlinux.conf from the fat partition
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/5b6489f7-09bc-415d-9d7f-40035d6c202b";
    fsType = "f2fs";
    options = [ "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/9BA7-2596";
    fsType = "vfat";
    options = [ "noatime" ];
  };

  boot.tmp.useTmpfs = true;

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

  # 1gb of ddr3: zstd zram at 150% with high swappiness keeps ram footprint small
  # and prevents micro-sd wear from swap thrashing
  zramSwap = {
    enable = true;
    memoryPercent = 150;
  };
}
