# armbian's u-boot (built with rockchip's rk3328 ddr blob, mainline tpl cannot
# init the ddr3 on this board) and its board dtb, lifted from
# linux-u-boot-mkspi-current 26.08.0-trunk / armbian-mkspi 1.3.3
{ runCommand }:

runCommand "mkspi-firmware" { } ''
  install -Dm644 ${./u-boot-rockchip.bin} $out/u-boot-rockchip.bin
  install -Dm644 ${./rk3328-mkspi.dtb} $out/rockchip/rk3328-mkspi.dtb
''
