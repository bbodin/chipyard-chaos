if {[info exists ::env(OUT_DIR)]} {
  set out_dir $::env(OUT_DIR)
} else {
  puts "OUT_DIR env var not set"
  exit 1
}

read_db "$out_dir/pre_write_design"

# Read liberty libraries for leakage power.
foreach lib [glob -nocomplain /root/.conda-sky130/share/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/*.lib] {
  read_liberty $lib
}
foreach lib [glob -nocomplain /root/.conda-sky130/share/pdk/sky130A/libs.ref/sky130_fd_io/lib/*.lib] {
  read_liberty $lib
}

# Read constraints/parasitics if present (helps power/timing context).
if {[file exists "$out_dir/Rocket.mapped.sdc"]} {
  if {[catch {read_sdc "$out_dir/Rocket.mapped.sdc"} sdc_err]} {
    puts "WARN: read_sdc failed: $sdc_err"
  }
}
if {[file exists "$out_dir/Rocket.par.spef"]} {
  read_spef "$out_dir/Rocket.par.spef"
}

# Default activity is used if no VCD/SAIF is provided.
puts "POWER_REPORT_BEGIN"
report_power
puts "POWER_REPORT_END"
