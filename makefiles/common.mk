SHELL := /bin/bash
.DELETE_ON_ERROR:

TARGET ?= rocket
OUT_SUFFIX =

DOCKER_OVERLAYS ?= rocket-configs/overlay boom-configs/overlay
DOCKER_DEPS = $(shell find $(DOCKER_OVERLAYS) -type f 2>/dev/null)

DOCKERFILE ?= Dockerfile

CHIPYARD_CONFIG ?= CustomRocketConfig
CHIPYARD_TOP ?= Rocket
VLSI_CONF ?= sky130-rocket.yml

VLSI_OBJ_DIR ?= build-sky130-openroad
CHIPYARD_VLSI_DIR ?= /root/chipyard/vlsi
CHIPYARD_VLSI_OBJ ?= $(CHIPYARD_VLSI_DIR)/$(VLSI_OBJ_DIR)/chipyard.harness.TestHarness.$(CHIPYARD_CONFIG)-ChipTop

DOCKER_IMAGE ?= chipyard-proto
DOCKER_CONTAINER ?= chipyard-proto-runner
DOCKER_START_DEPS ?=

ifeq ($(TARGET),boom)
CHIPYARD_CONFIG = SmallBoomV3Config
CHIPYARD_TOP = BoomCore
VLSI_OBJ_DIR = build-sky130-openroad-boom
VLSI_CONF = sky130-boom.yml
OUT_SUFFIX = .boom
endif

LOG_PREFIX ?=
LOG_PREFIX_BASENAMES = build test plot_violations benchmark syn par power syn_power verilog
LOG_FILES = $(foreach n,$(LOG_PREFIX_BASENAMES),$(LOG_PREFIX)$(n)$(OUT_SUFFIX).log)
.PRECIOUS: $(LOG_FILES)
CLEAN_FILES = $(LOG_FILES)
CLEAN_FILES += $(LOG_PREFIX)violations$(OUT_SUFFIX).png $(LOG_PREFIX)violations$(OUT_SUFFIX).csv
CLEAN_FILES += $(LOG_PREFIX)power$(OUT_SUFFIX).rpt $(LOG_PREFIX)syn_power$(OUT_SUFFIX).rpt $(LOG_PREFIX)power_saif$(OUT_SUFFIX).rpt
CLEAN_FILES += custom_vlog$(OUT_SUFFIX).txt

define run_on_docker
cid=$$(docker ps -q --filter "name=^/$(DOCKER_CONTAINER)$$" | head -n 1); \
if [ -z "$$cid" ]; then cid=$$(docker ps -q --filter ancestor=$(DOCKER_IMAGE) | head -n 1); fi; \
if [ -z "$$cid" ]; then echo "No running $(DOCKER_IMAGE) container found"; exit 1; fi; \
docker exec $$cid /bin/bash -lc "source /root/chipyard/env.sh && $(1)"
endef

define run_on_docker_raw
cid=$$(docker ps -q --filter "name=^/$(DOCKER_CONTAINER)$$" | head -n 1); \
if [ -z "$$cid" ]; then cid=$$(docker ps -q --filter ancestor=$(DOCKER_IMAGE) | head -n 1); fi; \
if [ -z "$$cid" ]; then echo "No running $(DOCKER_IMAGE) container found"; exit 1; fi; \
docker exec $$cid /bin/bash -lc "$(1)"
endef

define docker_cp_to
cid=$$(docker ps -q --filter "name=^/$(DOCKER_CONTAINER)$$" | head -n 1); \
if [ -z "$$cid" ]; then cid=$$(docker ps -q --filter ancestor=$(DOCKER_IMAGE) | head -n 1); fi; \
if [ -z "$$cid" ]; then echo "No running $(DOCKER_IMAGE) container found"; exit 1; fi; \
docker cp $(1) $$cid:$(2)
endef



clean:
	rm -f $(CLEAN_FILES)
