set proj_name "ct_demo"
set bd_name   "ct_bd"
set part      "xczu9eg-ffvb1156-2-e"

file delete -force ./build
create_project ${proj_name} ./build -part ${part} -force
set_property board_part xilinx.com:zcu102:part0:3.4 [current_project]

# Add VHDL Files
set src_dir [file dirname [info script]]/src
add_files -norecurse [glob ${src_dir}/*.vhd]
set_property file_type {VHDL} [get_files *.vhd]

# Add Constraints
add_files -fileset constrs_1 -norecurse ./constraints/*.xdc

# Create Block Design
create_bd_design ${bd_name}
current_bd_design ${bd_name}

create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} [get_bd_cells zynq_ultra_ps_e_0]

set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {1} CONFIG.PSU__USE__S_AXI_HP0 {0} CONFIG.PSU__USE__S_AXI_HP2 {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__I2C1__PERIPHERAL__ENABLE {1} CONFIG.PSU__I2C1__PERIPHERAL__IO {MIO 16 .. 17} \
    CONFIG.PSU__UART0__PERIPHERAL__ENABLE {1} CONFIG.PSU__UART0__PERIPHERAL__IO {MIO 18 .. 19} \
] [get_bd_cells zynq_ultra_ps_e_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
set_property -dict [list CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000} CONFIG.USE_LOCKED {false} CONFIG.USE_RESET {false}] [get_bd_cells clk_wiz_0]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins clk_wiz_0/clk_in1]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_ctrl
set_property -dict [list CONFIG.C_GPIO_WIDTH {2} CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_IS_DUAL {0}] [get_bd_cells axi_gpio_ctrl]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_config
set_property -dict [list CONFIG.C_GPIO_WIDTH {8} CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_IS_DUAL {0}] [get_bd_cells axi_gpio_config]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_status
set_property -dict [list CONFIG.C_GPIO_WIDTH {32} CONFIG.C_ALL_INPUTS {1} CONFIG.C_IS_DUAL {1}] [get_bd_cells axi_gpio_status]

foreach slave {axi_gpio_ctrl/S_AXI axi_gpio_config/S_AXI axi_gpio_status/S_AXI} {
    apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/zynq_ultra_ps_e_0/M_AXI_HPM0_FPD" Clk "Auto"} [get_bd_intf_pins $slave]
}

assign_bd_address -offset 0xA0010000 -range 64K [get_bd_addr_segs axi_gpio_ctrl/S_AXI/Reg]
assign_bd_address -offset 0xA0020000 -range 64K [get_bd_addr_segs axi_gpio_config/S_AXI/Reg]
assign_bd_address -offset 0xA0030000 -range 64K [get_bd_addr_segs axi_gpio_status/S_AXI/Reg]
assign_bd_address -offset 0xA0030008 -range 64K [get_bd_addr_segs axi_gpio_status/S_AXI/Reg2]

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins zynq_ultra_ps_e_0/maxihpm1_fpd_aclk] [get_bd_pins zynq_ultra_ps_e_0/saxihpe0_fpd_aclk]

create_bd_cell -type module -reference ct_top_simple u_ct_top

create_bd_port -dir I -from 3 -to 0 -type data diff_in_p
create_bd_port -dir I -from 3 -to 0 -type data diff_in_n
create_bd_port -dir O diff_out_p_0
create_bd_port -dir O diff_out_n_0
create_bd_port -dir O -from 4 -to 0 term
create_bd_port -dir O -from 4 -to 0 oe

connect_bd_net [get_bd_ports diff_in_p] [get_bd_pins u_ct_top/diff_in_p]
connect_bd_net [get_bd_ports diff_in_n] [get_bd_pins u_ct_top/diff_in_n]
connect_bd_net [get_bd_ports diff_out_p_0] [get_bd_pins u_ct_top/diff_out_p_0]
connect_bd_net [get_bd_ports diff_out_n_0] [get_bd_pins u_ct_top/diff_out_n_0]
connect_bd_net [get_bd_ports term] [get_bd_pins u_ct_top/term]
connect_bd_net [get_bd_ports oe] [get_bd_pins u_ct_top/oe]

connect_bd_net [get_bd_pins axi_gpio_ctrl/gpio_io_o] [get_bd_pins u_ct_top/en_i]
connect_bd_net [get_bd_pins axi_gpio_config/gpio_io_o] [get_bd_pins u_ct_top/config]
connect_bd_net [get_bd_pins u_ct_top/fifo_ts] [get_bd_pins axi_gpio_status/gpio_io_i]
connect_bd_net [get_bd_pins u_ct_top/fifo_data] [get_bd_pins axi_gpio_status/gpio2_io_i]

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins u_ct_top/clk_axi]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins u_ct_top/clk_fast]

create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins proc_sys_reset_0/ext_reset_in]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_reset] [get_bd_pins u_ct_top/rst]

regenerate_bd_layout
validate_bd_design
save_bd_design
make_wrapper -files [get_files ${bd_name}.bd] -top
add_files -norecurse ./build/${proj_name}.srcs/sources_1/bd/${bd_name}/hdl/${bd_name}_wrapper.v
set_property top ${bd_name}_wrapper [current_fileset]
generate_target all [get_files ${bd_name}.bd]

launch_runs synth_1 -jobs 8
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
write_hw_platform -fixed -force -include_bit -file ./${bd_name}.xsa
