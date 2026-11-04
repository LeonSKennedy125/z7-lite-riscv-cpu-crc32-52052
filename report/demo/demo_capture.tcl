# Demo VIO capture: send one RESTART and read the 104-word mailbox.
# Args: <bit> <ltx> <out.hex> <program 0|1>
set bit [lindex $argv 0]
set ltx [lindex $argv 1]
set out [lindex $argv 2]
set do_program [lindex $argv 3]

proc hexval {probe key width} {
    set raw [get_property $key $probe]
    if {![regexp {^[0-9a-fA-F]+$} $raw] || [string length $raw] > (($width + 3) / 4)} {
        error "invalid $key: $raw"
    }
    set value [expr "0x$raw"]
    if {$value < 0 || $value >= (1 << $width)} { error "probe value exceeds width: $raw" }
    return $value
}

open_hw_manager
connect_hw_server -url localhost:3121
set targets [get_hw_targets -quiet]
if {[llength $targets] != 1} { error "expected exactly one JTAG target, got [llength $targets]" }
open_hw_target [lindex $targets 0]
set device ""
foreach candidate [get_hw_devices] {
    if {[string tolower [get_property PART $candidate]] eq "xc7z010"} { set device $candidate }
}
if {$device eq ""} { error "no xc7z010 device found" }
current_hw_device $device
set_property PROBES.FILE $ltx $device
if {$do_program == 1} {
    set_property PROGRAM.FILE $bit $device
    puts "DEMO_PROGRAMMING"
    flush stdout
    program_hw_devices $device
}
refresh_hw_device $device
set vios [get_hw_vios -of_objects $device]
if {[llength $vios] != 1} { error "expected exactly one VIO, got [llength $vios]" }
set vio [lindex $vios 0]
set probes [get_hw_probes -of_objects $vio]
set found [dict create]
foreach probe $probes {
    set name [get_property NAME $probe]
    regsub {\[[0-9]+:[0-9]+\]$} $name {} name
    dict set found $name $probe
    if {[get_property TYPE $probe] eq "vio_input"} {
        set_property INPUT_VALUE_RADIX HEX $probe
    } else {
        set_property OUTPUT_VALUE_RADIX HEX $probe
    }
}
foreach need {read_data committed failed read_index restart} {
    if {![dict exists $found $need]} { error "missing VIO probe $need" }
}
set index [dict get $found read_index]
set restart [dict get $found restart]
set data [dict get $found read_data]
set done [dict get $found committed]
set failed [dict get $found failed]

# Start from low and request a VIO auxiliary reset.
set_property OUTPUT_VALUE 0 $restart
set_property OUTPUT_VALUE [format %02x 0] $index
commit_hw_vio $vio
refresh_hw_vio -update_output_values $vio
puts "DEMO_RESTART_LOW"
flush stdout
set_property OUTPUT_VALUE 1 $restart
commit_hw_vio $vio
after 20
refresh_hw_vio -update_output_values $vio
if {[hexval $done INPUT_VALUE 1] != 0} { error "mailbox did not clear under reset" }
puts "DEMO_RESTART_ASSERTED"
flush stdout
set_property OUTPUT_VALUE 0 $restart
commit_hw_vio $vio
puts "DEMO_RESTART_RELEASED"
flush stdout

set completed 0
for {set poll 0} {$poll < 300} {incr poll} {
    after 100
    refresh_hw_vio $vio
    if {[hexval $done INPUT_VALUE 1] == 1} { set completed 1; break }
}
if {!$completed} { error "firmware timeout waiting for committed" }
if {[hexval $failed INPUT_VALUE 1] != 0} { error "failed probe asserted" }
puts "DEMO_COMMITTED"
flush stdout

set handle [open $out {WRONLY CREAT TRUNC}]
try {
    for {set i 0} {$i < 104} {incr i} {
        set_property OUTPUT_VALUE [format %02x $i] $index
        commit_hw_vio $vio
        after 2
        refresh_hw_vio $vio
        if {[hexval $done INPUT_VALUE 1] != 1 || [hexval $failed INPUT_VALUE 1] != 0} {
            error "status changed during mailbox scan at word $i"
        }
        puts $handle [format %08x [hexval $data INPUT_VALUE 32]]
    }
} finally {
    close $handle
}
puts "DEMO_DONE"
flush stdout
close_hw_target
disconnect_hw_server
close_hw_manager
