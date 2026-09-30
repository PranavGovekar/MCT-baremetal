# Bare-Metal FMC-DIO Coincidence Trigger Demo
Standalone Vitis/Vivado project for the ZCU102 + FMC-DIO-5CH-TTL-A card.
Runs bare-metal C code to initialize the DAC, pulse-stretch inputs, and print
raw 15-combination coincidence events to the UART serial terminal.

## Build Instructions
1. Open your Xilinx Terminal (ensure vivado, xsct, and bootgen are in PATH).
2. `cd fmc_dio_ct_demo`
3. `chmod +x build.sh`
4. `./build.sh`
5. Copy the generated `BOOT.BIN` to the root of a FAT32 SD card and boot the ZCU102.
# MCT-baremetal
