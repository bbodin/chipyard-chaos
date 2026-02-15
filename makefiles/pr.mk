.PHONY: par

par: par$(OUT_SUFFIX).log

par$(OUT_SUFFIX).log:
	# Place & route inside the container.
	@set -o pipefail; \
	$(call run_on_docker,cd /root/chipyard/vlsi && make par tech_name=sky130 CONFIG=$(CHIPYARD_CONFIG) VLSI_TOP=$(CHIPYARD_TOP) VLSI_OBJ_DIR=$(VLSI_OBJ_DIR) ENABLE_YOSYS_FLOW=1 INPUT_CONFS=$(VLSI_CONF)) 2>&1 | tee par$(OUT_SUFFIX).log

.PHONY: plot

plot: plot_violations$(OUT_SUFFIX).log

plot_violations$(OUT_SUFFIX).log:
	@set -o pipefail; \
	python3 scripts/plot_violations.py --log par$(OUT_SUFFIX).log --out violations$(OUT_SUFFIX).png --csv violations$(OUT_SUFFIX).csv --last 2>&1 | tee plot_violations$(OUT_SUFFIX).log
