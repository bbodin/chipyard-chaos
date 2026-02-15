.PHONY: verilog custom_vlog

verilog: verilog$(OUT_SUFFIX).log

verilog$(OUT_SUFFIX).log: docker-start
	@set -o pipefail; \
	$(call run_on_docker,make -C /root/chipyard/sims/verilator CONFIG=$(CHIPYARD_CONFIG) verilog) 2>&1 | tee verilog$(OUT_SUFFIX).log

custom_vlog: custom_vlog$(OUT_SUFFIX).txt

custom_vlog$(OUT_SUFFIX).txt: verilog$(OUT_SUFFIX).log
	@set -e; \
	$(call run_on_docker,cat /root/chipyard/sims/verilator/generated-src/chipyard.harness.TestHarness.$(CHIPYARD_CONFIG)/chipyard.harness.TestHarness.$(CHIPYARD_CONFIG).top.f) > custom_vlog$(OUT_SUFFIX).txt
