# Read only the routed checkpoint produced by this S03 attempt.
if {[version -short] ne "2026.1"} {error "Vivado2026.1 required"}
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root evidence static]
file mkdir $out
set checkpoint [file join $root evidence routed.dcp]
if {[llength $argv] == 1} {set checkpoint [lindex $argv 0]}
open_checkpoint $checkpoint
proc emit {name value} {
    global out
    set f [open [file join $out $name] w]
    puts $f $value
    close $f
}
proc property_or_empty {obj name} {
    if {[llength $obj] == 0 || [lsearch -exact [list_property $obj] $name] < 0} {return ""}
    return [get_property $name $obj]
}
emit tool_version.txt [version]
if {[get_property PART [current_design]] ne "xc7z010clg400-1"} {error "wrong device"}
report_timing_summary -report_unconstrained -check_timing_verbose -max_paths 10 -file [file join $out timing_summary.rpt]
report_timing -delay_type max -max_paths 100 -nworst 2 -input_pins -file [file join $out setup.rpt]
report_timing -delay_type min -max_paths 100 -nworst 2 -input_pins -file [file join $out hold.rpt]
report_pulse_width -limit 20 -file [file join $out pulse_width.rpt]
check_timing -verbose -file [file join $out check_timing.rpt]
report_clocks -file [file join $out clocks.rpt]
report_clock_networks -file [file join $out clock_networks.rpt]
report_clock_interaction -file [file join $out clock_interaction.rpt]
report_cdc -details -file [file join $out cdc.rpt]
report_bus_skew -warn_on_violation -file [file join $out bus_skew.rpt]
report_debug_core -file [file join $out debug_cores.rpt]
report_exceptions -coverage -file [file join $out exceptions_coverage.rpt]
report_exceptions -ignored -file [file join $out exceptions_ignored.rpt]
report_disable_timing -file [file join $out disabled_timing.rpt]
report_timing -user_ignored -max_paths 100 -file [file join $out ignored_paths.rpt]
report_route_status -file [file join $out route_status.rpt]
report_io -file [file join $out io.rpt]
report_utilization -hierarchical -file [file join $out utilization.rpt]
report_ram_utilization -file [file join $out ram_utilization.rpt]
write_xdc -force [file join $out constraints_merged.xdc]
report_drc -file [file join $out drc.rpt]
set f [open [file join $out drc_violations.tsv] w]
puts $f "name\trule\tseverity\tdescription"
foreach v [get_drc_violations -quiet] {
    puts $f "[get_property NAME $v]\t[property_or_empty $v RULE]\t[get_property SEVERITY $v]\t[property_or_empty $v DESCRIPTION] [property_or_empty $v DETAILS]"
}
close $f
report_drc -checks [get_drc_checks LUTLP-1] -file [file join $out combinational_loops.rpt]
foreach v [get_drc_violations -quiet] {
    if {[string match LUTLP-1* [get_property NAME $v]]} {error "unresolved LUTLP-1"}
}
report_methodology -file [file join $out methodology.rpt]
report_methodology -json [file join $out methodology.json]
set f [open [file join $out methodology_violations.tsv] w]
puts $f "name\trule\tseverity\tdescription"
foreach v [get_methodology_violations -quiet] {
    puts $f "[get_property NAME $v]\t[property_or_empty $v RULE]\t[get_property SEVERITY $v]\t[property_or_empty $v DESCRIPTION] [property_or_empty $v DETAILS]"
}
close $f
set f [open [file join $out clocks.tsv] w]
puts $f "name\tperiod\twaveform\tgenerated\tmaster\tsource_pins"
foreach c [get_clocks] {
    puts $f "[get_property NAME $c]\t[get_property PERIOD $c]\t[get_property WAVEFORM $c]\t[get_property IS_GENERATED $c]\t[get_property MASTER_CLOCK $c]\t[get_property SOURCE_PINS $c]"
}
close $f
set mmcms [get_cells -hier -filter {REF_NAME == MMCME2_ADV}]
set f [open [file join $out mmcm_properties.rpt] w]
foreach c $mmcms {
    puts $f "CELL=$c"
    foreach p {DIVCLK_DIVIDE CLKFBOUT_MULT_F CLKOUT0_DIVIDE_F CLKIN1_PERIOD STARTUP_WAIT LOC} {
        puts $f "$p=[get_property $p $c]"
    }
}
close $f
set f [open [file join $out bram.tsv] w]
puts $f "name\tprimitive\tDOA_REG\tDOB_REG\tREAD_WIDTH_A\tWRITE_WIDTH_A\tLOC"
set dtcm_count 0
set bram36 [get_cells -hier -filter {REF_NAME == RAMB36E1}]
set bram18 [get_cells -hier -filter {REF_NAME == RAMB18E1}]
foreach c [concat $bram36 $bram18] {
    puts $f "[get_property NAME $c]\t[get_property REF_NAME $c]\t[get_property DOA_REG $c]\t[get_property DOB_REG $c]\t[get_property READ_WIDTH_A $c]\t[get_property WRITE_WIDTH_A $c]\t[get_property LOC $c]"
    if {[string match *u_DTCM* [get_property NAME $c]]} {
        incr dtcm_count
        if {[get_property DOA_REG $c] != 1} {error "DTCM output register disabled"}
    }
}
close $f
if {$dtcm_count != 16 || [llength $bram36]+0.5*[llength $bram18] > 48} {error "BRAM capacity gate failed"}
set f [open [file join $out reset_structure.tsv] w]
puts $f "name\tprimitive\tASYNC_REG\tclock"
foreach c [get_cells -hier -filter {NAME =~ *cpu_reset_sync_0* && IS_PRIMITIVE == 1}] {
    puts $f "[get_property NAME $c]\t[get_property REF_NAME $c]\t[get_property ASYNC_REG $c]\t[get_clocks -quiet -of_objects [get_pins -quiet -of_objects $c -filter {IS_CLOCK == 1}]]"
}
close $f
set reset_cells [get_cells -hier -filter {NAME =~ *cpu_reset_sync_0* && IS_SEQUENTIAL == 1}]
report_timing -from $reset_cells -delay_type max -max_paths 30 -file [file join $out reset_release_setup.rpt]
report_timing -from $reset_cells -delay_type min -max_paths 30 -file [file join $out reset_release_hold.rpt]
set async_pins [get_pins -hier -filter {REF_PIN_NAME == CLR || REF_PIN_NAME == PRE}]
report_timing -to $async_pins -delay_type max -max_paths 30 -file [file join $out recovery.rpt]
report_timing -to $async_pins -delay_type min -max_paths 30 -file [file join $out removal.rpt]
set ready [get_nets -hier -filter {NAME == ready}]
if {[llength $ready] != 1} {error "ready net audit is ambiguous"}
set ready_drivers [get_pins -of_objects $ready -filter {DIRECTION == OUT}]
set ready_sources [all_fanin -flat -startpoints_only -to $ready_drivers]
set f [open [file join $out ready_fanin.txt] w]
puts $f "NET=$ready\nDRIVERS=$ready_drivers\nSTARTPOINTS=$ready_sources"
foreach pin $ready_sources {
    set c [get_cells -of_objects $pin]
    puts $f "SOURCE=$pin REF_NAME=[get_property REF_NAME $c]"
    if {![string match *buffered_reg* $pin]} {error "ready depends on an unexpected source: $pin"}
}
close $f
set f [open [file join $out bram_control_fanin.tsv] w]
puts $f "target\tstartpoint\tprimitive"
set async_control_sources 0
set control_cache [dict create]
set controls_checked 0
foreach c [get_cells -hier -filter {REF_NAME == RAMB36E1 && NAME =~ *u_DTCM*}] {
    foreach pin [get_pins -of_objects $c -filter {REF_PIN_NAME =~ WEA* || REF_PIN_NAME == ENARDEN || REF_PIN_NAME == REGCEAREGCE || REF_PIN_NAME == RSTRAMARSTRAM || REF_PIN_NAME == RSTREGARSTREG}] {
        incr controls_checked
        set key [lindex [lsort [get_nets -segments -of_objects $pin]] 0]
        if {![dict exists $control_cache $key]} {
            set source_cells [all_fanin -flat -startpoints_only -only_cells -to $pin]
            set records [list]
            if {[llength $source_cells] > 0} {
                foreach source $source_cells ref [get_property REF_NAME $source_cells] {
                    lappend records [list $source $ref]
                }
            }
            dict set control_cache $key $records
        }
        foreach record [dict get $control_cache $key] {
            lassign $record source ref
            puts $f "$pin\t$source\t$ref"
            if {$ref in {FDCE FDPE FDCPE}} {incr async_control_sources}
        }
    }
}
close $f
emit structural_summary.txt "PART=[get_property PART [current_design]]\nRAMB36=[llength $bram36]\nRAMB18=[llength $bram18]\nDTCM_RAMB36=$dtcm_count\nDTCM_ASYNC_CONTROL_SOURCES=$async_control_sources\nDTCM_CONTROL_PINS_CHECKED=$controls_checked\nDTCM_UNIQUE_CONTROL_NETS=[dict size $control_cache]\nREADY_SOURCES=[llength $ready_sources]\nMMCM_COUNT=[llength $mmcms]"
if {$async_control_sources != 0} {error "DTCM control has asynchronous register sources"}
puts "S03_ROUTED_AUDIT_COMPLETE"
close_design
