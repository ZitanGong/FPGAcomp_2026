set_device -name GW5AST-138B GW5AST-LV138PG484AC1/I0

add_file src/audio_core.v
add_file src/top.v
add_file src/audio/i2s_tx.v
add_file src/audio/pt8211_tx.v
add_file src/clock/reset_sync.v
add_file src/key/key_filter.v
add_file src/key/scan165.v
add_file src/key/button_debounce.v
add_file src/synth/adsr.v
add_file src/synth/div16.v
add_file src/synth/mix21.v
add_file src/synth/sine_rom.v
add_file src/synth/synth21.v
add_file src/synth/voice.v
add_file constraints/neo31005.cst
add_file constraints/audio.sdc

set_option -top_module top
set_option -verilog_std v2001
set_option -output_base_name synth21
run all
