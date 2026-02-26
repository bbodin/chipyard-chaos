SHELL := /bin/bash
.DELETE_ON_ERROR:

DOCKER_OVERLAYS ?= rocket-configs/overlay boom-configs/overlay
DOCKER_DEPS = $(shell find $(DOCKER_OVERLAYS) -type f 2>/dev/null)
DOCKERFILE ?= Dockerfile
CHIPYARD_VLSI_DIR ?= /root/chipyard/vlsi

DOCKER_IMAGE ?= chipyard-proto
DOCKER_CONTAINER ?= chipyard-proto-runner
DOCKER_START_DEPS ?=

TARGET ?= rocket

ifeq ($(TARGET),boom)
	CHIPYARD_CONFIG = SmallBoomV3Config
	CHIPYARD_TOP = BoomCore
	VLSI_OBJ_DIR = build-sky130-openroad-boom
	VLSI_CONF = sky130-boom.yml
	OUT_SUFFIX = .boom
else ifeq ($(TARGET),rocket)
	CHIPYARD_CONFIG ?= TinyRocketConfig
	CHIPYARD_TOP ?= ChipTop
	VLSI_CONF ?= sky130-rocket.yml
	VLSI_OBJ_DIR = build-sky130-openroad-rocket
	OUT_SUFFIX = .rocket
else ifeq ($(TARGET),customrocket)
	CHIPYARD_CONFIG ?= CustomRocketConfig
	CHIPYARD_TOP ?= ChipTop
	VLSI_CONF ?= sky130-rocket.yml
	VLSI_OBJ_DIR = build-sky130-openroad-customrocket
	OUT_SUFFIX = .customrocket
else ifeq ($(TARGET),customboom)
	CHIPYARD_CONFIG ?= CustomBoomConfig
	CHIPYARD_TOP ?= BoomCore
	VLSI_CONF ?= sky130-boom.yml
	VLSI_OBJ_DIR = build-sky130-openroad-customboom
	OUT_SUFFIX = .customboom
else
$(error Unsupported TARGET: $(TARGET))
endif




CHIPYARD_VLSI_OBJ ?= $(CHIPYARD_VLSI_DIR)/$(VLSI_OBJ_DIR)/chipyard.harness.TestHarness.$(CHIPYARD_CONFIG)-ChipTop

LOG_PREFIX ?=
LOG_PREFIX_BASENAMES = build test plot_violations benchmark syn par power syn_power verilog
LOG_FILES = $(foreach n,$(LOG_PREFIX_BASENAMES),$(LOG_PREFIX)$(n)$(OUT_SUFFIX).log)
.PRECIOUS: $(LOG_FILES)
CLEAN_FILES = $(LOG_FILES)
CLEAN_FILES += $(LOG_PREFIX)violations$(OUT_SUFFIX).png $(LOG_PREFIX)violations$(OUT_SUFFIX).csv
CLEAN_FILES += $(LOG_PREFIX)power$(OUT_SUFFIX).rpt $(LOG_PREFIX)syn_power$(OUT_SUFFIX).rpt $(LOG_PREFIX)power_saif$(OUT_SUFFIX).rpt
CLEAN_FILES += custom_vlog$(OUT_SUFFIX).txt



clean:
	rm -f $(CLEAN_FILES)
