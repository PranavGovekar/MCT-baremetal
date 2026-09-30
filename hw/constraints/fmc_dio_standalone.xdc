# =========================================================================
# ZCU102 FMC-DIO 5CH TTL-A Constraints (HPC0)
# =========================================================================

# --- HIT INPUTS (Ch1-Ch4 as Inputs) ---
# CH0 (Ch1) - HPC0 LA33 - Bank 65
set_property PACKAGE_PIN V12 [get_ports {diff_in_p[0]}]
set_property PACKAGE_PIN V11 [get_ports {diff_in_n[0]}]
set_property IOSTANDARD LVDS [get_ports {diff_in_p[0]}]
set_property IOSTANDARD LVDS [get_ports {diff_in_n[0]}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {diff_in_p[0]}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {diff_in_n[0]}]

# CH1 (Ch2) - HPC0 LA20 - Bank 66
set_property PACKAGE_PIN N13 [get_ports {diff_in_p[1]}]
set_property PACKAGE_PIN M13 [get_ports {diff_in_n[1]}]
set_property IOSTANDARD LVDS [get_ports {diff_in_p[1]}]
set_property IOSTANDARD LVDS [get_ports {diff_in_n[1]}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {diff_in_p[1]}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {diff_in_n[1]}]

# CH2 (Ch3) - HPC0 LA16 - Bank 66
set_property PACKAGE_PIN Y12 [get_ports {diff_in_p[2]}]
set_property PACKAGE_PIN AA12 [get_ports {diff_in_n[2]}]
set_property IOSTANDARD LVDS [get_ports {diff_in_p[2]}]
set_property IOSTANDARD LVDS [get_ports {diff_in_n[2]}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {diff_in_p[2]}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {diff_in_n[2]}]

# CH3 (Ch4) - HPC0 LA03 - Bank 65
set_property PACKAGE_PIN Y2 [get_ports {diff_in_p[3]}]
set_property PACKAGE_PIN Y1 [get_ports {diff_in_n[3]}]
set_property IOSTANDARD LVDS [get_ports {diff_in_p[3]}]
set_property IOSTANDARD LVDS [get_ports {diff_in_n[3]}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {diff_in_p[3]}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {diff_in_n[3]}]

# --- OUTPUT (Ch5 as Output) ---
set_property PACKAGE_PIN T7 [get_ports diff_out_p_0]
set_property PACKAGE_PIN T6 [get_ports diff_out_n_0]
set_property IOSTANDARD LVDS [get_ports diff_out_p_0]
set_property IOSTANDARD LVDS [get_ports diff_out_n_0]

# --- OE & TERM ---
# SN74LVT125 OE is Active-LOW. 
# Ch1-4 (Inputs) -> OE=1 (High-Z). Ch5 (Output) -> OE=0 (Drive).
set_property PACKAGE_PIN V6  [get_ports {oe[0]}]
set_property PACKAGE_PIN K12 [get_ports {oe[1]}]
set_property PACKAGE_PIN Y9  [get_ports {oe[2]}]
set_property PACKAGE_PIN AB6 [get_ports {oe[3]}]
set_property PACKAGE_PIN AB3 [get_ports {oe[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {oe[*]}]

# TERM (50 Ohm) -> Active-HIGH (1 = Enabled)
set_property PACKAGE_PIN U6  [get_ports {term[0]}]
set_property PACKAGE_PIN AC1 [get_ports {term[1]}]
set_property PACKAGE_PIN AC3 [get_ports {term[2]}]
set_property PACKAGE_PIN W2  [get_ports {term[3]}]
set_property PACKAGE_PIN W1  [get_ports {term[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {term[*]}]
