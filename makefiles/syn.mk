.PHONY: syn

syn: syn$(OUT_SUFFIX).log

syn$(OUT_SUFFIX).log:
	# Synthesis inside the container.
	@set -o pipefail; \
	$(call run_on_docker,cd /root/chipyard/vlsi && make syn tech_name=sky130 CONFIG=$(CHIPYARD_CONFIG) VLSI_TOP=$(CHIPYARD_TOP) VLSI_OBJ_DIR=$(VLSI_OBJ_DIR) ENABLE_YOSYS_FLOW=1 INPUT_CONFS=$(VLSI_CONF)) 2>&1 | tee syn$(OUT_SUFFIX).log
