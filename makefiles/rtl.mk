.PHONY: verilog

verilog: verilog$(OUT_SUFFIX).log

verilog$(OUT_SUFFIX).log:
	@set -o pipefail; \
	$(call run_on_docker,make -C /root/chipyard/sims/verilator CONFIG=$(CHIPYARD_CONFIG) verilog) 2>&1 | tee verilog$(OUT_SUFFIX).log

