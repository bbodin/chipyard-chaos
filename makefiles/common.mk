SHELL := /bin/bash
.DELETE_ON_ERROR:

DOCKERFILE ?= Dockerfile
CHIPYARD_VLSI_DIR ?= /root/chipyard/vlsi

DOCKER_IMAGE ?= chipyard-proto
DOCKER_CONTAINER ?= chipyard-proto-runner
DOCKER_START_DEPS ?=

TARGET ?= rocket

ifeq ($(TARGET),boom)
	CHIPYARD_CONFIG = SmallBoomV3Config
	CHIPYARD_TOP = BoomCore
	VLSI_CONF = sky130-boom.yml
else ifeq ($(TARGET),rocket)
	CHIPYARD_CONFIG ?= TinyRocketConfig
	CHIPYARD_TOP ?= ChipTop
	VLSI_CONF ?= sky130-rocket.yml
else ifeq ($(TARGET),customrocket)
	CHIPYARD_CONFIG ?= CustomRocketConfig
	CHIPYARD_TOP ?= ChipTop
	VLSI_CONF ?= sky130-rocket.yml
else ifeq ($(TARGET),parametricrocket)
	CHIPYARD_CONFIG ?= ParametricRocketConfig
	CHIPYARD_TOP ?= ChipTop
	VLSI_CONF ?= sky130-rocket.yml
else ifeq ($(TARGET),customboom)
	CHIPYARD_CONFIG ?= CustomBoomConfig
	CHIPYARD_TOP ?= BoomCore
	VLSI_CONF ?= sky130-boom.yml
else
$(error Unsupported TARGET: $(TARGET))
endif


OUT_SUFFIX = .$(TARGET)
VLSI_OBJ_DIR = build-sky130-openroad-$(TARGET)

CHIPYARD_VLSI_OBJ ?= $(CHIPYARD_VLSI_DIR)/$(VLSI_OBJ_DIR)/chipyard.harness.TestHarness.$(CHIPYARD_CONFIG)-ChipTop

LOG_PREFIX ?=
LOG_PREFIX_BASENAMES = build test plot_violations benchmark syn par power syn_power verilog
LOG_FILES = $(foreach n,$(LOG_PREFIX_BASENAMES),$(LOG_PREFIX)$(n)$(OUT_SUFFIX).log)
.PRECIOUS: $(LOG_FILES)
CLEAN_FILES = $(LOG_FILES)
CLEAN_FILES += $(LOG_PREFIX)violations$(OUT_SUFFIX).png $(LOG_PREFIX)violations$(OUT_SUFFIX).csv
CLEAN_FILES += $(LOG_PREFIX)power$(OUT_SUFFIX).rpt $(LOG_PREFIX)syn_power$(OUT_SUFFIX).rpt $(LOG_PREFIX)power_saif$(OUT_SUFFIX).rpt




clean:
	rm -f $(CLEAN_FILES)
