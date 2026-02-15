.PHONY: power syn_power

power : power$(OUT_SUFFIX).rpt

power$(OUT_SUFFIX).rpt:
	# Power report prerequisites (inside the container):
	#   Run: `make test` to launch the $(DOCKER_IMAGE) container.
	#   Required DB:
	#     par-rundir/pre_write_design
	# Optional (improves accuracy):
	#     par-rundir/Rocket.mapped.sdc
	#     par-rundir/Rocket.par.spef
	#   PDK libs:
	#   /root/.conda-sky130/share/pdk/sky130A/libs.ref/sky130_fd_*/lib/*.lib
	# Output:
	#  power.rpt
	@set -o pipefail; \
	$(call docker_cp_to,$(PWD)/scripts/run_power_report.tcl,/tmp/run_power_report.tcl); \
	$(call run_on_docker_raw,OUT_DIR=$(CHIPYARD_VLSI_OBJ)/par-rundir /root/.conda-openroad/bin/openroad -no_init -exit /tmp/run_power_report.tcl) 2>&1 | tee $(PWD)/power$(OUT_SUFFIX).log && \
	awk '/POWER_REPORT_BEGIN/{p=1;next} /POWER_REPORT_END/{p=0} p' $(PWD)/power$(OUT_SUFFIX).log > $(PWD)/power$(OUT_SUFFIX).rpt

syn_power : syn_power$(OUT_SUFFIX).rpt

syn_power$(OUT_SUFFIX).rpt:
	# Fast power (synthesis only, no routing/parasitics).
	# Required netlists:
	#   syn-rundir/*.v
	# Optional constraints:
	#   syn-rundir/*.sdc
	# Output:
	#   syn_power.rpt
	@set -o pipefail; \
	$(call docker_cp_to,$(PWD)/scripts/run_syn_power_report.tcl,/tmp/run_syn_power_report.tcl); \
	$(call run_on_docker_raw,TOP=$(CHIPYARD_TOP) OUT_DIR=$(CHIPYARD_VLSI_OBJ)/syn-rundir /root/.conda-openroad/bin/openroad -no_init -exit /tmp/run_syn_power_report.tcl) 2>&1 | tee $(PWD)/syn_power$(OUT_SUFFIX).log && \
	awk '/POWER_REPORT_BEGIN/{p=1;next} /POWER_REPORT_END/{p=0} p' $(PWD)/syn_power$(OUT_SUFFIX).log > $(PWD)/syn_power$(OUT_SUFFIX).rpt
