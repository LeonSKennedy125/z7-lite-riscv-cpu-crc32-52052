if {[version -short] ne "2026.1"} {error "Vivado2026.1 required"}
set root [file normalize [file join [file dirname [info script]] ..]]
open_hw_manager
connect_hw_server -url localhost:3121
set targets [get_hw_targets -quiet]
if {[llength $targets]==0} {error "HARDWARE_PENDING: no JTAG targets; board not connected"}
if {[llength $targets]!=1} {error "ambiguous JTAG targets; do not program an arbitrary board"}
open_hw_target [lindex $targets 0]
set devices [get_hw_devices -quiet -filter {PART =~ xc7z010*}]
if {[llength $devices]!=1} {error "expected exactly one xc7z010 device"}
if {[lindex $argv 0] ne "R11"} {error "PCB_REVISION_REQUIRED: verify the physical board against vendor R11 schematic, then pass --pcb-revision R11"}
set device [lindex $devices 0]
current_hw_device $device
set_property PROGRAM.FILE [file join $root evidence demo.bit] $device
set_property PROBES.FILE [file join $root evidence demo.ltx] $device
program_hw_devices $device
refresh_hw_device $device
set vios [get_hw_vios -of_objects $device]
if {[llength $vios]!=1} {error "expected exactly one result VIO"}
set vio [lindex $vios 0]
refresh_hw_vio -update_output_values $vio
proc probe {vio type pattern} {
    set p [get_hw_probes -of_objects $vio -filter "TYPE == $type && NAME =~ $pattern"]
    if {[llength $p]!=1} {error "probe lookup ambiguous/missing: $type $pattern"}
    return [lindex $p 0]
}
set index [probe $vio vio_output *read_index*]
set restart [probe $vio vio_output *restart*]
set data [probe $vio vio_input *read_data*]
set done [probe $vio vio_input *committed*]
file mkdir [file join $root evidence hardware]
for {set run 0} {$run<3} {incr run} {
    set_property OUTPUT_VALUE 0 $index
    set_property OUTPUT_VALUE 1 $restart
    commit_hw_vio $vio
    after 20
    refresh_hw_vio $vio
    if {[get_property INPUT_VALUE $done] ne "0"} {error "mailbox did not clear during reset"}
    set_property OUTPUT_VALUE 0 $restart
    commit_hw_vio $vio
    set completed 0
    for {set poll 0} {$poll<300} {incr poll} {
        after 100
        refresh_hw_vio $vio
        if {[get_property INPUT_VALUE $done] eq "1"} {set completed 1;break}
    }
    if {!$completed} {error "hardware firmware timeout on run $run"}
    set out [open [file join $root evidence hardware run_$run.hex] w]
    for {set i 0} {$i<104} {incr i} {
        set_property OUTPUT_VALUE [format %02x $i] $index
        commit_hw_vio $vio
        after 2
        refresh_hw_vio $vio
        set word [get_property INPUT_VALUE $data]
        if {![regexp {^[[:xdigit:]]{1,8}$} $word]} {error "invalid hardware word $word"}
        puts $out [format %08x [expr 0x$word]]
    }
    close $out
    puts "HARDWARE_CAPTURE run=$run device=$device"
}
close_hw_target
disconnect_hw_server
close_hw_manager
puts "HARDWARE_CAPTURE_COMPLETE: three actual reset runs; host validation still required"
