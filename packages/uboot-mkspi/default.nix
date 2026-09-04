# the mks-pi is a roc-rk3328-cc clone, so it takes that defconfig and dtb.
# nixpkgs ships rock64 and rock-pi-e for rk3328 and neither carries the ddr3
# init the mks-pi needs
{
  buildUBoot,
  armTrustedFirmwareRK3328,
}:

buildUBoot {
  defconfig = "roc-cc-rk3328_defconfig";
  extraMeta.platforms = [ "aarch64-linux" ];
  env.BL31 = "${armTrustedFirmwareRK3328}/bl31.elf";
  filesToInstall = [ "u-boot-rockchip.bin" ];
}
