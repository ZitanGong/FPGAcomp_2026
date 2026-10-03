# The GW5AST OSC primitive supplies u_osc/OSCOUT.default_clk at 52.5 MHz;
# Gowin creates that base-clock constraint automatically.

# GAO TCK <= 20 MHz; independent of all processing clocks.
create_clock -name tck_pad_i -period 50.000 [get_ports {tck_pad_i}]
set_clock_groups -asynchronous -group [get_clocks {tck_pad_i}]

set_false_path -from [get_ports {key_in[*] key0_n key1_n key2_n}]
set_max_delay 100.000 -to [get_ports {shld key_clk hp_bclk hp_sd hp_ws dbg_frame dbg_key dbg_err dbg_ref pa_n dbg_rst}]
set_min_delay 0.000 -to [get_ports {shld key_clk hp_bclk hp_sd hp_ws dbg_frame dbg_key dbg_err dbg_ref pa_n dbg_rst}]

set_false_path -from [get_ports {touch_scl touch_sda touch_irq_n}]
set_max_delay 100.000 -to [get_ports {touch_scl touch_sda led_data led_clk led_lat}]
set_min_delay 0.000 -to [get_ports {touch_scl touch_sda led_data led_clk led_lat}]
