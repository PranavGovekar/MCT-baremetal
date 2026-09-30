#!/bin/bash
set -e

echo "=== [1/3] Building Vivado Hardware ==="
vivado -mode batch -source hw/build_vivado.tcl

echo "=== [2/3] Building Vitis Software ==="
xsct hw/build_vitis.tcl

echo "=== [3/3] Generating BOOT.BIN ==="
cat <<EOF > boot.bif
the_ROM_image:
{
    [fsbl_config] a53_x64
    [bootloader] ./build/vitis_workspace/zynqmp_fsbl.elf
    [destination_device=pl] ./build/ct_bd.runs/impl_1/ct_bd_wrapper.bit
    [destination_cpu=a53_0] ./build/vitis_workspace/ct_app/Release/ct_app.elf
}
EOF

bootgen -arch zynqmp -image boot.bif -o BOOT.BIN -w
echo "=== SUCCESS! Copy BOOT.BIN to the root of your SD card and boot. ==="
