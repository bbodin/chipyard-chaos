.PHONY: benchmark mm
.PRECIOUS: mm$(OUT_SUFFIX).log benchmark$(OUT_SUFFIX).log


mm: mm$(OUT_SUFFIX).log
benchmark: benchmark$(OUT_SUFFIX).log

benchmark$(OUT_SUFFIX).log:
	@set -o pipefail; \
	$(call run_on_docker,make -C /root/chipyard/sims/verilator CONFIG=$(CHIPYARD_CONFIG) && make -C /root/chipyard/sims/verilator CONFIG=$(CHIPYARD_CONFIG) run-bmark-tests) 2>&1 | tee benchmark$(OUT_SUFFIX).log

mm$(OUT_SUFFIX).log:
	@set -o pipefail; \
	$(call run_on_docker,ulimit -s 13054 && make -C /root/chipyard/sims/verilator CONFIG=$(CHIPYARD_CONFIG) && make -C /root/chipyard/sims/verilator CONFIG=$(CHIPYARD_CONFIG)  run-binary BINARY=/root/chipyard/.conda-env/riscv-tools/riscv64-unknown-elf/share/riscv-tests/benchmarks/mm.riscv) 2>&1 | tee mm$(OUT_SUFFIX).log
