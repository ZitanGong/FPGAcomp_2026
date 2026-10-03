set_device -name GW5AST-138B GW5AST-LV138PG484AC1/I0

add_file src/audio_core.v
add_file src/top.v
add_file src/touch/i2c_reg.v
add_file src/touch/mpr121.v
add_file src/touch/touch_map.v
add_file src/touch/led595.v
add_file src/touch/touch_led.v
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
add_file -type gao src/touch_dbg.rao

set_option -top_module top
set_option -verilog_std v2001
set_option -output_base_name synth21
set ch [open constraints/neo31005.cst r]
set cst [read $ch]
close $ch
set used_pins [dict create]
foreach line [split $cst "\n"] {
    if {[regexp {^\s*IO_LOC\s+"([^"]+)"\s+([A-Z]+[0-9]+)\s*;} $line -> port pin]} {
        if {[dict exists $used_pins $pin]} {
            error "Pin conflict: $port and [dict get $used_pins $pin] both use $pin"
        }
        dict set used_pins $pin $port
    }
}
set pins_ok 1
foreach port {led_data led_clk led_lat} {
    if {![regexp -line "^IO_LOC +\"$port\" +\[A-Z\]+\[0-9\]+;" $cst]} {
        puts "LED pin not assigned: $port (constraints/neo31005.cst)"
        set pins_ok 0
    }
}
if {$pins_ok} {
    run all
} else {
    run syn
    puts "SYNTHESIS ONLY: assign all three LED pins before place-and-route."
}
