if {[info exists ::env(OUT_DIR)]} {
  set out_dir $::env(OUT_DIR)
} else {
  puts "OUT_DIR env var not set"
  exit 1
}

if {[info exists ::env(TOP)]} {
  set top $::env(TOP)
} else {
  set top "Rocket"
}

file mkdir "$out_dir/reports"

# Minimal tech/LEF to satisfy OpenROAD database requirements.
set techlef "/root/.conda-sky130/share/pdk/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef"
if {[file exists $techlef]} {
  read_lef $techlef
}
set stdlef "/root/.conda-sky130/share/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef"
if {[file exists $stdlef]} {
  read_lef $stdlef
}

# Read liberty libraries for leakage power.
foreach lib [glob -nocomplain /root/.conda-sky130/share/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/*.lib] {
  read_liberty $lib
}
foreach lib [glob -nocomplain /root/.conda-sky130/share/pdk/sky130A/libs.ref/sky130_fd_io/lib/*.lib] {
  read_liberty $lib
}

# Read synthesis netlists.
set netlists [glob -nocomplain "$out_dir/*.v"]
if {[llength $netlists] == 0} {
  puts "No Verilog netlists found in $out_dir"
  exit 1
}
read_verilog $netlists
link_design $top

# Read constraints if present.
set sdcs [glob -nocomplain "$out_dir/*.sdc"]
foreach sdc $sdcs {
  if {[catch {read_sdc $sdc} sdc_err]} {
    puts "WARN: read_sdc failed for $sdc: $sdc_err"
  }
}

# No parasitics at this stage; report leakage-dominated power.
puts "POWER_REPORT_BEGIN"
report_power
puts "POWER_REPORT_END"
