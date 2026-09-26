set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
open_project [file join $root fpga_project1.gprj]
set_option -top_module top
set_option -output_base_name synth21
set_option -synthesis_tool gowinsynthesis
set_option -verilog_std v2001
set_option -use_sspi_as_gpio 1
set_option -use_mspi_as_gpio 1
set_option -use_cpu_as_gpio 1
run all
