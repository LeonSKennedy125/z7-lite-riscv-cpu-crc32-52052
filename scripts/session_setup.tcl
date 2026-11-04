# Vivado2026.1 GOLD supports disabling telemetry (UG973, Tools Telemetry).
# This native user-definable parameter changes this Tcl process only; unlike
# telemetry_data -disable it does not save a per-user preference.
if {[version -short] ne "2026.1"} {error "Vivado2026.1 required"}
report_param debug.enable_data_collection
puts "S03_R1_TELEMETRY_BEFORE=[get_param debug.enable_data_collection]"
set_param debug.enable_data_collection false
if {[get_param debug.enable_data_collection] != 0} {error "session telemetry collection remains enabled"}
puts "S03_R1_TELEMETRY_SESSION_ONLY=[get_param debug.enable_data_collection]"
