# The GW5AST OSC primitive supplies u_osc/OSCOUT.default_clk at 52.5 MHz;
# Gowin creates that base-clock constraint automatically.

set_false_path -from [get_ports {key_in[*] key0_n key1_n key2_n}]
set_max_delay 100.000 -to [get_ports {shld key_clk hp_bclk hp_sd hp_ws dbg_frame dbg_key dbg_err dbg_ref pa_n dbg_rst}]
set_min_delay 0.000 -to [get_ports {shld key_clk hp_bclk hp_sd hp_ws dbg_frame dbg_key dbg_err dbg_ref pa_n dbg_rst}]
