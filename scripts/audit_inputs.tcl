proc crc_demo_audit_inputs {root} {
    # Audit the files actually registered with Vivado, including IP init files.
    set audit [file join $root evidence dependencies]
    file mkdir $audit
    set tool_root [file normalize [file join $::env(XILINX_VIVADO)]]
    proc inside_tree {path base} {
        set path [string tolower [string map {\\ /} [file normalize $path]]]
        set base [string trimright [string tolower [string map {\\ /} [file normalize $base]]] /]
        return [expr {$path eq $base || [string first "$base/" $path] == 0}]
    }
    set crc_audit_channel [open [file join $audit registered_files.tsv] w]
    puts $crc_audit_channel "path\tclass\texists"
    foreach item [get_files -all -quiet] {
        set p [file normalize [get_property NAME $item]]
        if {[inside_tree $p $root]} {set class package_or_new_generated} elseif {[inside_tree $p $tool_root]} {set class vivado_installation} else {error "external design input rejected: $p"}
        puts $crc_audit_channel "$p\t$class\t[file exists $p]"
    }
    close $crc_audit_channel
    foreach module {DTCM I_ROM} filename {ram.coe rom.coe} {
        set ip [get_ips $module]
        set p [file normalize [file join [file dirname [get_property IP_FILE $ip]] [get_property CONFIG.Coe_File $ip]]]
        if {$p ne [file normalize [file join $root firmware out $filename]]} {error "external COE reference rejected: $p"}
        if {![file isfile $p]} {error "COE missing"}
    }
    foreach fs {sources_1 sim_1} {
        set crc_audit_channel [open [file join $audit ${fs}_compile_order.txt] w]
        puts $crc_audit_channel [join [get_files -compile_order sources -used_in [expr {$fs eq "sources_1" ? "synthesis" : "simulation"}] -of_objects [get_filesets $fs]] "\n"]
        close $crc_audit_channel
        foreach p [get_property include_dirs [get_filesets $fs]] {
            if {![inside_tree $p $root]} {error "external include directory rejected: $p"}
        }
    }
    puts "DEPENDENCY_PATH_AUDIT_PASS root=$root tools=$tool_root"
}
crc_demo_audit_inputs $root
