# MicroPhase Z7-LITE_ES1 / H251800347: user-confirmed paired Rev1_1 vendor package.
# Historical filename retained for build-manifest compatibility; the actual PCB is ES1.
# Vendor schematic: https://github.com/MicroPhase/fpga-docs/blob/master/schematic/Z7-LITE_R11.pdf
# Vendor English manual: source/DEV_BOARD/Z7-LITE/Z7-Lite_Reference_Manual.md
create_clock -name sys_clk_50 -period 20.000 [get_ports clock]
set_input_jitter [get_clocks sys_clk_50] 0.200
set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS33} [get_ports clock]
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33} [get_ports resetn]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW} [get_ports led_ok]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW} [get_ports led_heartbeat]
# LEDs have no receiving sampling clock; no fictional board output delay is assigned.
set_false_path -to [get_ports {led_ok led_heartbeat}]
# The button is an asynchronous reset request. Internal reset-release paths remain timed.
set_false_path -from [get_ports resetn]
# Vendor Rev1_1 schematic page4: K6 VCCO_0=3.3V, M6 CFGBVS=3.3V.
# F11 VCCBATT_0=1.8V is a different supply. R47 pulls up PROGRAM_B_0.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
