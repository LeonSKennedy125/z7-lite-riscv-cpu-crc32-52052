# Multi-round VIO demo: send N RESTART commands, forward + reverse mailbox scans.
# Args: <bit> <ltx> <out_dir> <program 0|1> <runs>
set bit [lindex $argv 0]
set ltx [lindex $argv 1]
set outdir [lindex $argv 2]
set do_program [lindex $argv 3]
set runs [lindex $argv 4]

proc emit {line} { puts $line; flush stdout }

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
set target [lindex $targets 0]
emit "TARGET [get_property UID $target]"
open_hw_target $target
set device ""
foreach candidate [get_hw_devices] {
    if {[string tolower [get_property PART $candidate]] eq "xc7z010"} { set device $candidate }
}
if {$device eq ""} { error "no xc7z010 device found" }
current_hw_device $device
emit "DEVICE [get_property PART $device] IDCODE [get_property IDCODE $device]"
set_property PROBES.FILE $ltx $device
if {$do_program == 1} {
    set_property PROGRAM.FILE $bit $device
    emit "PROGRAM_BEGIN"
    program_hw_devices $device
    emit "PROGRAM_END"
}
refresh_hw_device $device
set vios [get_hw_vios -of_objects $device]
if {[llength $vios] != 1} { error "expected exactly one VIO, got [llength $vios]" }
set vio [lindex $vios 0]
emit "VIO [get_property INSTANCE_NAME $vio]"
set probes [get_hw_probes -of_objects $vio]
if {[llength $probes] != 5} { error "expected 5 VIO probes, got [llength $probes]" }
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

proc read_status {vio done failed} {
    refresh_hw_vio $vio
    return [list [hexval $done INPUT_VALUE 1] [hexval $failed INPUT_VALUE 1]]
}

proc scan {vio index data done failed run pass direction outdir} {
    emit "SCAN_START $run $pass $direction"
    array set words {}
    set order {}
    if {$direction eq "forward"} {
        for {set i 0} {$i < 104} {incr i} { lappend order $i }
    } else {
        for {set i 103} {$i >= 0} {incr i -1} { lappend order $i }
    }
    foreach i $order {
        set_property OUTPUT_VALUE [format %02x $i] $index
        commit_hw_vio $vio
        after 2
        lassign [read_status $vio $done $failed] committed failedv
        if {$committed != 1 || $failedv != 0} { error "status changed during scan run $run pass $pass word $i" }
        set value [format %08x [hexval $data INPUT_VALUE 32]]
        set words($i) $value
        emit "PROGRESS $run $pass $i $value"
    }
    set handle [open [file join $outdir run_${run}_scan_${pass}.hex] {WRONLY CREAT TRUNC}]
    try {
        for {set i 0} {$i < 104} {incr i} { puts $handle $words($i) }
    } finally {
        close $handle
    }
    emit "SCAN_END $run $pass 104"
}

for {set run 0} {$run < $runs} {incr run} {
    emit "ROUND_START $run"
    set_property OUTPUT_VALUE 0 $restart
    set_property OUTPUT_VALUE [format %02x 0] $index
    commit_hw_vio $vio
    refresh_hw_vio -update_output_values $vio
    if {[hexval $restart OUTPUT_VALUE 1] != 0} { error "restart did not reach low state" }
    emit "RESTART_LOW $run"
    set_property OUTPUT_VALUE 1 $restart
    commit_hw_vio $vio
    after 20
    refresh_hw_vio -update_output_values $vio
    if {[hexval $restart OUTPUT_VALUE 1] != 1} { error "restart did not reach asserted state" }
    lassign [read_status $vio $done $failed] committed failedv
    if {$committed != 0} { error "mailbox did not clear under reset" }
    emit "RESTART_ASSERTED $run"
    set_property OUTPUT_VALUE 0 $restart
    commit_hw_vio $vio
    emit "RESTART_RELEASED $run"
    set completed 0
    for {set poll 0} {$poll < 300} {incr poll} {
        after 100
        lassign [read_status $vio $done $failed] committed failedv
        if {$failedv != 0} { error "failed probe asserted on run $run" }
        if {$committed == 1} { set completed 1; break }
    }
    if {!$completed} { error "firmware timeout on run $run" }
    emit "COMMITTED $run"
    scan $vio $index $data $done $failed $run 0 forward $outdir
    after 1000
    scan $vio $index $data $done $failed $run 1 reverse $outdir
    set fwd [open [file join $outdir run_${run}_scan_0.hex]]
    set rev [open [file join $outdir run_${run}_scan_1.hex]]
    try {
        set i 0
        while {[gets $fwd line] >= 0} {
            if {[gets $rev other] < 0 || $line ne $other} {
                error "forward/reverse scan mismatch on run $run word $i"
            }
            incr i
        }
        if {$i != 104} { error "expected 104 words on run $run, got $i" }
    } finally {
        close $fwd; close $rev
    }
    emit "ROUND_END $run MATCH"
}
emit "DEMO_DONE $runs"
close_hw_target
disconnect_hw_server
close_hw_manager
