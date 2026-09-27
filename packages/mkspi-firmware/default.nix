# armbian's u-boot (built with rockchip's rk3328 ddr blob, mainline tpl cannot
# init the ddr3 on this board) and its board dtb, lifted from
# linux-u-boot-mkspi-current 26.08.0-trunk / armbian-mkspi 1.3.3
#
# the dtb wires dwc3 to armbian's out-of-tree inno usb3 phy; mainline has no
# driver for it so dwc3 defers forever and the usb3 port stays dead. dropping
# the phy refs matches mainline rk3328.dtsi
{ runCommand, dtc }:

runCommand "mkspi-firmware" { nativeBuildInputs = [ dtc ]; } ''
  install -Dm644 ${./u-boot-rockchip.bin} $out/u-boot-rockchip.bin
  install -Dm644 ${./rk3328-mkspi.dtb} $out/rockchip/rk3328-mkspi.dtb
  install -Dm644 ${./rtw8812a_fw.bin} $out/lib/firmware/rtw88/rtw8812a_fw.bin
  fdtput -d $out/rockchip/rk3328-mkspi.dtb /usb@ff600000 phys
  fdtput -d $out/rockchip/rk3328-mkspi.dtb /usb@ff600000 phy-names
''
