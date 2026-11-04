if {[version -short] ne "2026.1"} {error "Vivado2026.1 required"}
set root [file normalize [file join [file dirname [info script]] ..]]
set action [lindex $argv 0]
proc add_unique {files {fileset sources_1}} {
 foreach f $files {
  if {[llength [get_files -quiet -all */[file tail $f]]]==0} {add_files -fileset $fileset $f}
 }
}
proc run_checked_simulation {root dir top} {
    if {[get_property target_simulator [current_project]] ne "XSim"} {error "XSim required"}
    # UG937 documents local IP-model compilation. Avoid the failing precompiled
    # library xsim.ini delete/reopen path; do not patch the tool installation.
    set_property sim.use_ip_compiled_libs 0 [current_project]
    if {[get_property sim.use_ip_compiled_libs [current_project]] != 0} {error "local IP model compilation required"}
    puts "SIMULATION_PREFLIGHT part=[get_property PART [current_project]] simulator=XSim mode=behavioral top=$top ip_precompiled=0 watchdog=in_testbench"
    update_compile_order -fileset sim_1
    # UG835 scripts_only preserves Vivado's source order and IP library flags.
    # Use a source-controlled Tcl driver: a zero-byte generated top.tcl must
    # never turn into an apparently successful zero-time simulation.
    # Retain prior validated mailbox captures; scripts/objects are regenerated
    # by this launch and each test must still produce fresh terminal evidence.
    launch_simulation -mode behavioral -scripts_only -noclean_dir
    set f [open [file join $dir simulate.bat] r];set script [read $f];close $f
    if {![regexp {call xsim[ \t]+([^ \r\n]+)} $script -> snapshot]} {error "generated XSim snapshot missing"}
    set previous [pwd];cd $dir
    puts "SIM_BATCH_PHASE compile";puts [exec cmd.exe /d /c [file nativename [file join $dir compile.bat]] 2>@1]
    puts "SIM_BATCH_PHASE elaborate";puts [exec cmd.exe /d /c [file nativename [file join $dir elaborate.bat]] 2>@1]
    puts "SIM_BATCH_PHASE simulate snapshot=$snapshot driver=[file join $root scripts run_sim.tcl]"
    puts [exec cmd.exe /d /c xsim $snapshot -tclbatch [file join $root scripts run_sim.tcl] -log simulate.log 2>@1]
    cd $previous
}
if {$action eq "unit"} {
    create_project crc_unit [file join $root b u] -part xc7z010clg400-1 -force
    add_files [file join $root src crc_mmio.sv]
    add_files -fileset sim_1 [file join $root sim tb_crc.sv]
    foreach f {expected.hex lengths.hex} {add_files -fileset sim_1 [file join $root firmware out $f]}
    set_property top tb_crc [get_filesets sim_1]
    set_property xsim.simulate.runtime all [get_filesets sim_1]
    run_checked_simulation $root [file join $root b u crc_unit.sim sim_1 behav xsim] tb_crc
    exit
}
set proj [file join $root b p demo.xpr]
if {[file exists $proj]} {
    open_project $proj
} else {
    create_project demo [file dirname $proj] -part xc7z010clg400-1
}
    config_ip_cache -disable_cache
    set_property sim.use_ip_compiled_libs 0 [current_project]
    set_property target_language Verilog [current_project]
    set listing [open [file join $root scripts rtl_files.txt] r]
    foreach rel [split [read $listing] "\n"] {
        if {$rel eq ""} {continue}
        if {[file pathtype $rel] ne "relative" || [string match *..* $rel]} {error "unsafe RTL manifest entry"}
        if {![file isfile [file join $root $rel]]} {error "missing RTL input $rel"}
        add_unique [list [file join $root $rel]]
    }
    close $listing
    set_property include_dirs [list [file join $root src core]] [get_filesets sources_1]
    add_unique [list [file join $root constraints board_r11.xdc]] constrs_1
    set_property top demo_top [get_filesets sources_1]
    # Standalone IPs are generated for this part; no old DCP or IP cache is consumed.
    proc make_ip {name module cfg} {
        if {[llength [get_ips -quiet $module]]==0} {create_ip -name $name -vendor xilinx.com -library ip -module_name $module}
        set_property -dict $cfg [get_ips $module]
        foreach {key value} $cfg {
            set actual [get_property $key [get_ips $module]]
            if {$key eq "CONFIG.Coe_File"} {
                set actual [file normalize [file join [file dirname [get_property IP_FILE [get_ips $module]]] $actual]]
                set value [file normalize $value]
            }
            if {[string is double -strict $value] && [string is double -strict $actual]} {
                if {abs($value-$actual)>0.001} {error "IP readback mismatch $module $key $actual != $value"}
            } elseif {![string equal -nocase $value $actual]} {error "IP readback mismatch $module $key $actual != $value"}
        }
        puts "IP_CONFIG_READBACK_PASS $module"
    }
    make_ip blk_mem_gen DTCM [list CONFIG.Memory_Type Single_Port_RAM CONFIG.Write_Width_A 32 CONFIG.Read_Width_A 32 \
      CONFIG.Write_Depth_A 16384 CONFIG.Use_Byte_Write_Enable true CONFIG.Byte_Size 8 \
      CONFIG.Enable_A Use_ENA_Pin CONFIG.Register_PortA_Output_of_Memory_Primitives true \
      CONFIG.Register_PortA_Output_of_Memory_Core false CONFIG.Load_Init_File true \
      CONFIG.Coe_File [file join $root firmware out ram.coe] CONFIG.Use_RSTA_Pin false]
    make_ip blk_mem_gen I_ROM [list CONFIG.Memory_Type Single_Port_ROM CONFIG.Write_Width_A 32 \
      CONFIG.Write_Depth_A 4096 CONFIG.Enable_A Use_ENA_Pin CONFIG.Register_PortA_Output_of_Memory_Primitives false \
      CONFIG.Register_PortA_Output_of_Memory_Core false CONFIG.Load_Init_File true \
      CONFIG.Coe_File [file join $root firmware out rom.coe] CONFIG.Use_RSTA_Pin false]
    make_ip clk_wiz clk50 [list CONFIG.PRIM_IN_FREQ 50.000 CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 50.000 \
      CONFIG.PRIM_SOURCE No_buffer CONFIG.RESET_TYPE ACTIVE_LOW CONFIG.RESET_PORT resetn]
    make_ip proc_sys_reset rstip [list CONFIG.C_EXT_RESET_HIGH 0 CONFIG.C_AUX_RESET_HIGH 0]
    make_ip util_vector_logic invip [list CONFIG.C_OPERATION not CONFIG.C_SIZE 1]
    make_ip util_vector_logic orip [list CONFIG.C_OPERATION or CONFIG.C_SIZE 1]
    make_ip vio vio_result [list CONFIG.C_NUM_PROBE_IN 3 CONFIG.C_NUM_PROBE_OUT 2 \
      CONFIG.C_PROBE_IN0_WIDTH 32 CONFIG.C_PROBE_IN1_WIDTH 1 CONFIG.C_PROBE_IN2_WIDTH 1 \
      CONFIG.C_PROBE_OUT0_WIDTH 7 CONFIG.C_PROBE_OUT1_WIDTH 1 \
      CONFIG.C_PROBE_OUT0_INIT_VAL 0x00 CONFIG.C_PROBE_OUT1_INIT_VAL 0x0]
    set_property generate_synth_checkpoint false [get_files *.xci]
    generate_target all [get_ips]
    export_ip_user_files -of_objects [get_ips] -no_script -sync -force -quiet
    add_unique [list [file join $root sim tb_cpu.sv] [file join $root sim tb_cpu_faults.sv] [file join $root sim tb_memory.sv]] sim_1
    foreach f {expected.hex lengths.hex symbols.hex} {add_unique [list [file join $root firmware out $f]] sim_1}
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1
source [file join $root scripts audit_inputs.tcl]
if {$action eq "project"} {
    report_ip_status -file [file join $root evidence ip_status.txt]
    # Vivado settles DTCM UI metadata after the first memory-model run.
    # Prime this newly generated model inside project generation (XCI is an output).
    # The separate memory gate then repeats the full test under immutable raw XCI hashes.
    set_property top tb_memory [get_filesets sim_1]
    run_checked_simulation $root [file join $root b p demo.sim sim_1 behav xsim] tb_memory
    set_property top tb_cpu [get_filesets sim_1]
    export_simulation -simulator xsim -directory [file join $root b export] -force
    puts "PROJECT_CREATED_7010_50MHZ"
} elseif {$action in {simulate memory fault_timeout fault_error}} {
    if {$action eq "memory"} {set top tb_memory} elseif {$action eq "simulate"} {set top tb_cpu} else {set top tb_cpu_$action}
    set_property top $top [get_filesets sim_1]
    set_property xsim.simulate.runtime all [get_filesets sim_1]
    run_checked_simulation $root [file join $root b p demo.sim sim_1 behav xsim] $top
} elseif {$action eq "implement"} {
    set_property top demo_top [get_filesets sources_1]
    source [file join $root scripts session_setup.tcl]
    foreach run {synth_1 impl_1} {
        set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs $run]
        if {[get_property INCREMENTAL_CHECKPOINT [get_runs $run]] ne ""} {error "incremental checkpoint configured"}
    }
    set_property STEPS.SYNTH_DESIGN.TCL.PRE [file join $root scripts session_setup.tcl] [get_runs synth_1]
    set_property STEPS.OPT_DESIGN.TCL.PRE [file join $root scripts session_setup.tcl] [get_runs impl_1]
    set_property STEPS.WRITE_BITSTREAM.TCL.PRE [file join $root scripts session_setup.tcl] [get_runs impl_1]
    puts "FRESH_SOURCE_NO_INCREMENTAL_NO_IP_CACHE"
    if {[get_property STATUS [get_runs synth_1]] ne "Not started"} {reset_run synth_1}
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "synthesis did not complete"}
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "implementation did not complete"}
    open_run impl_1
    report_utilization -file [file join $root evidence utilization.rpt]
    report_utilization -hierarchical -file [file join $root evidence utilization_hierarchical.rpt]
    report_timing_summary -report_unconstrained -check_timing_verbose -file [file join $root evidence timing_summary.rpt]
    report_drc -file [file join $root evidence drc.rpt]
    report_methodology -file [file join $root evidence methodology.rpt]
    report_clocks -file [file join $root evidence clocks.rpt]
    write_checkpoint -force [file join $root evidence routed.dcp]
    write_debug_probes -no_partial_ltxfile -force [file join $root evidence demo.ltx]
    file copy -force [file join $root b p demo.runs impl_1 demo_top.bit] [file join $root evidence demo.bit]
    set bram36 [get_cells -hier -filter {REF_NAME == RAMB36E1}]
    set bram18 [get_cells -hier -filter {REF_NAME == RAMB18E1}]
    set dtcm [get_cells -hier -filter {REF_NAME == RAMB36E1 && NAME =~ *u_DTCM*}]
    set f [open [file join $root evidence structure.txt] w]
    puts $f "PART=[get_property PART [current_project]]"
    puts $f "RAMB36=[llength $bram36] RAMB18=[llength $bram18] DTCM_RAMB36=[llength $dtcm]"
    set regok 1
    foreach cell $dtcm {if {[get_property DOA_REG $cell] != 1} {set regok 0}}
    puts $f "DTCM_DOA_REG=$regok"
    puts $f "SETUP_SLACK=[get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]"
    puts $f "HOLD_SLACK=[get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]"
    close $f
    if {[llength $bram36]+0.5*[llength $bram18]>48 || [llength $dtcm]!=16 || !$regok} {error "BRAM structure gate failed"}
    puts "IMPLEMENTATION_COMPLETE_7010_50MHZ"
}
close_project
