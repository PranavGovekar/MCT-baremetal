create_clock -period 10.000 -name pl_clk0 [get_ports pl_clk0]
create_clock -period 5.000 -name clk_fast [get_pins clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0]
set_clock_groups -asynchronous -group [get_clocks pl_clk0] -group [get_clocks clk_fast]
