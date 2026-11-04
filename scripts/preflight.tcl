if {[version -short] ne "2026.1"} {error "Vivado2026.1 required"}
set root [file normalize [file join [file dirname [info script]] ..]]
set out [open [file join $root evidence preflight.txt] w]
puts $out "VIVADO=[version -short]"
puts $out "PARTS=[get_parts -quiet xc7z010clg400-1]"
if {[llength [get_parts -quiet xc7z010clg400-1]] != 1} {close $out; error "7010 device support missing"}
open_hw_manager
if {[catch {connect_hw_server -url localhost:3121} why]} {
    puts $out "HW_SERVER_UNAVAILABLE=$why"
} else {
    set targets [get_hw_targets -quiet]
    puts $out "TARGET_COUNT=[llength $targets]"
    foreach t $targets {
        if {[catch {open_hw_target $t} why]} {puts $out "TARGET_ERROR=$why";continue}
        foreach d [get_hw_devices -quiet] {puts $out "DEVICE=$d PART=[get_property PART $d]"}
        close_hw_target
    }
    disconnect_hw_server
}
close_hw_manager
close $out
puts "PREFLIGHT_COMPLETE see evidence/preflight.txt; no device was programmed"
