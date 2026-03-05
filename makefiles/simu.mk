.PHONY: benchmark mm  vlsi-synth-package
.PRECIOUS: mm$(OUT_SUFFIX).log benchmark$(OUT_SUFFIX).log vlsi-synth-package$(OUT_SUFFIX).log

CHIPYARD_SIM_DIR ?= /root/chipyard/sims/verilator
CHIPYARD_VLSI_GEN_DIR ?= /root/chipyard/vlsi/generated-src/chipyard.harness.TestHarness.$(CHIPYARD_CONFIG)
CHIPYARD_VLSI_BUILD_DIR ?= /root/chipyard/vlsi/build/chipyard.harness.TestHarness.$(CHIPYARD_CONFIG)-$(CHIPYARD_TOP)
MM_BINARY ?= /root/chipyard/.conda-env/riscv-tools/riscv64-unknown-elf/share/riscv-tests/benchmarks/mm.riscv
MM_GEN_DIR = $(CHIPYARD_SIM_DIR)/generated-src/chipyard.harness.TestHarness.$(CHIPYARD_CONFIG)
VLSI_SYNTH_PACKAGE_DIR ?= vlsi-synth-package$(OUT_SUFFIX)


mm: mm$(OUT_SUFFIX).log
benchmark: benchmark$(OUT_SUFFIX).log
vlsi-synth-package: vlsi-synth-package$(OUT_SUFFIX).log

benchmark$(OUT_SUFFIX).log:
	@set -o pipefail; \
	$(call run_on_docker,make -C $(CHIPYARD_SIM_DIR) CONFIG=$(CHIPYARD_CONFIG) && make -C $(CHIPYARD_SIM_DIR) CONFIG=$(CHIPYARD_CONFIG) run-bmark-tests) 2>&1 | tee benchmark$(OUT_SUFFIX).log

mm$(OUT_SUFFIX).log:
	@set -o pipefail; \
	$(call run_on_docker,ulimit -s 13054 && make -C $(CHIPYARD_SIM_DIR) CONFIG=$(CHIPYARD_CONFIG) && make -C $(CHIPYARD_SIM_DIR) CONFIG=$(CHIPYARD_CONFIG) run-binary BINARY=$(MM_BINARY)) 2>&1 | tee mm$(OUT_SUFFIX).log

vlsi-synth-package$(OUT_SUFFIX).log:
	@set -o pipefail; \
	{ \
	set -e; \
	$(call run_on_docker,if [ ! -d $(CHIPYARD_VLSI_GEN_DIR) ]; then echo 'Missing VLSI generated-src: $(CHIPYARD_VLSI_GEN_DIR). Run synthesis or RTL generation in /root/chipyard/vlsi first.'; exit 1; fi); \
	rm -rf "$(VLSI_SYNTH_PACKAGE_DIR)"; \
	mkdir -p "$(VLSI_SYNTH_PACKAGE_DIR)/generated-src" "$(VLSI_SYNTH_PACKAGE_DIR)/build" "$(VLSI_SYNTH_PACKAGE_DIR)/configs"; \
	$(call docker_cp_from,$(CHIPYARD_VLSI_GEN_DIR),"$(VLSI_SYNTH_PACKAGE_DIR)/generated-src/"); \
	} 2>&1 | tee vlsi-synth-package$(OUT_SUFFIX).log
