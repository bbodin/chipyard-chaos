.PHONY: benchmark


benchmark: benchmark$(OUT_SUFFIX).log

benchmark$(OUT_SUFFIX).log:
	@set -o pipefail; \
	$(call run_on_docker,make -C /root/chipyard/sims/verilator CONFIG=$(CHIPYARD_CONFIG) && make -C /root/chipyard/sims/verilator CONFIG=$(CHIPYARD_CONFIG) run-bmark-tests) 2>&1 | tee benchmark$(OUT_SUFFIX).log
