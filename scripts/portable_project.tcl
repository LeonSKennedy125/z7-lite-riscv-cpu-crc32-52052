# Source-based companion to scripts/build.tcl; same seven IP configurations.
# Usage: vivado -mode batch -source scripts/portable_project.tcl -tclargs create|generate|test
if {[version -short] ne "2026.1"} {error "Vivado2026.1 required"}
set root [file normalize [file join [file dirname [info script]] ..]]
set action [lindex $argv 0]
if {$action ni {create generate test}} {error "Expected create, generate or test"}
set project_dir [file join $root vivado_project]
set project_file [file join $project_dir demo.xpr]
set results [file join $root evidence portable_project]
file mkdir $results
source [file join $root scripts session_setup.tcl]
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

if {$action eq "create"} {
    if {[file exists $project_file]} {error "Project already exists; use generate/test or a fresh checkout"}
    create_project demo $project_dir -part xc7z010clg400-1
    config_ip_cache -disable_cache
    set_property target_language Verilog [current_project]
    set_property target_simulator XSim [current_project]
    set_property sim.use_ip_compiled_libs 0 [current_project]
    set listing [open [file join $root scripts rtl_files.txt] r]
    foreach rel [split [read $listing] "\n"] {
        set rel [string trim $rel]
        if {$rel eq ""} {continue}
        if {[file pathtype $rel] ne "relative" || [string match *..* $rel]} {error "Unsafe RTL entry"}
        add_files [file join $root $rel]
    }
    close $listing
    foreach header {cpu_memory_map.vh riscv_define.vh} {add_files [file join $root src core $header]}
    set_property include_dirs [list [file join $root src core]] [get_filesets sources_1]
    set_property include_dirs [list [file join $root src core]] [get_filesets sim_1]
    add_files -fileset constrs_1 [file join $root constraints board_r11.xdc]
    set_property top demo_top [get_filesets sources_1]
    proc make_ip {name module cfg} {
        if {[llength [get_ips -quiet $module]]==0} {create_ip -name $name -vendor xilinx.com -library ip -module_name $module}
        # UG896: keep each COE next to its XCI. Vivado then writes the
        # basename natively, with a valid checksum and no machine dependency.
        set index [lsearch -exact $cfg CONFIG.Coe_File]
        if {$index >= 0} {
            set original [lindex $cfg [expr {$index+1}]]
            set local [file join [file dirname [get_property IP_FILE [get_ips $module]]] [file tail $original]]
            file copy -force $original $local
            set cfg [lreplace $cfg [expr {$index+1}] [expr {$index+1}] $local]
        }
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
      CONFIG.Coe_File [file join $root data frozen ram.coe] CONFIG.Use_RSTA_Pin false]
    make_ip blk_mem_gen I_ROM [list CONFIG.Memory_Type Single_Port_ROM CONFIG.Write_Width_A 32 \
      CONFIG.Write_Depth_A 4096 CONFIG.Enable_A Use_ENA_Pin CONFIG.Register_PortA_Output_of_Memory_Primitives false \
      CONFIG.Register_PortA_Output_of_Memory_Core false CONFIG.Load_Init_File true \
      CONFIG.Coe_File [file join $root data frozen rom.coe] CONFIG.Use_RSTA_Pin false]
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
    foreach tb {tb_crc.sv tb_cpu.sv tb_cpu_faults.sv tb_memory.sv} {
        add_files -fileset sim_1 [file join $root sim $tb]
    }
    foreach image {expected.hex lengths.hex symbols.hex} {
        add_files -fileset sim_1 [file join $root data frozen $image]
    }
    set_property top tb_cpu [get_filesets sim_1]
    set_property xsim.simulate.runtime all [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1
    close_project
    puts "PORTABLE_PROJECT_CREATED $project_file"
    return
}
open_project $project_file
if {[get_property PART [current_project]] ne "xc7z010clg400-1" || [get_property TOP [get_filesets sources_1]] ne "demo_top"} {
    error "Unexpected project identity"
}
if {[llength [get_ips]] != 7} {error "Expected seven IP instances"}
generate_target all [get_ips]
export_ip_user_files -of_objects [get_ips] -no_script -sync -force -quiet
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
report_ip_status -file [file join $results ip_status.rpt]
# Reject every source/config/init dependency outside this checkout or Vivado.
proc portable_inside {path base} {
    set p [string tolower [string map {\\ /} [file normalize $path]]]
    set b [string trimright [string tolower [string map {\\ /} [file normalize $base]]] /]
    return [expr {$p eq $b || [string first "$b/" $p] == 0}]
}
set out [open [file join $results dependencies.tsv] w]
puts $out "path\tclass\texists"
foreach f [get_files -all] {
    set p [file normalize [get_property NAME $f]]
    if {[portable_inside $p $root]} {set class checkout_or_new_generated} elseif {[portable_inside $p $::env(XILINX_VIVADO)]} {set class vivado_installation} else {error "External dependency: $p"}
    if {![file isfile $p]} {error "Missing input: $p"}
    puts $out "$p\t$class\t1"
}
close $out
set out [open [file join $results configuration.txt] w]
puts $out "VIVADO=[version -short] PART=[get_property PART [current_project]] TOP=[get_property TOP [get_filesets sources_1]]"
foreach module {DTCM I_ROM} image {ram.coe rom.coe} depth {16384 4096} reg {true false} {
    set ip [get_ips $module]
    set coe [file normalize [file join [file dirname [get_property IP_FILE $ip]] [get_property CONFIG.Coe_File $ip]]]
    if {$coe ne [file normalize [file join $project_dir demo.srcs sources_1 ip $module $image]] || ![file isfile $coe]} {error "Invalid relocated COE: $coe"}
    if {[get_property CONFIG.Write_Depth_A $ip] != $depth || [get_property CONFIG.Register_PortA_Output_of_Memory_Primitives $ip] ne $reg} {error "Memory contract changed"}
    puts $out "$module depth=$depth primitive_output_register=$reg coe=$coe"
}
foreach ip [get_ips] {puts $out "IP=[get_property NAME $ip] VLNV=[get_property IPDEF $ip] LOCKED=[get_property IS_LOCKED $ip]";if {[get_property IS_LOCKED $ip]} {error "Locked IP"}}
close $out
puts "PORTABLE_DEPENDENCY_AUDIT_PASS root=$root"
if {$action eq "test"} {
    foreach top {tb_crc tb_memory tb_cpu tb_cpu_fault_timeout tb_cpu_fault_error} {
        set_property top $top [get_filesets sim_1]
        set dir [file join $project_dir demo.sim sim_1 behav xsim]
        run_checked_simulation $root $dir $top
        set f [open [file join $dir simulate.log] r];set log [read $f];close $f
        if {![string match *TEST_PASS* $log] || [regexp -nocase {Fatal:|Error:|watchdog} $log]} {error "Simulation did not pass: $top"}
        file copy -force [file join $dir simulate.log] [file join $results ${top}.log]
        foreach file [glob -nocomplain [file join $dir mailbox_*.hex]] {file copy -force $file $results}
        puts "PORTABLE_SIMULATION_PASS $top"
    }
    set_property top tb_cpu [get_filesets sim_1]
    puts "PORTABLE_REGRESSION_PASS tests=5"
}
close_project
