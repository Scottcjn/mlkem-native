# Copyright (c) The mlkem-native project authors
# SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

PLATFORM_PATH := test/zephyr

# BUILD_DIR is set by the top-level Makefile after this file is included;
# define it here too so the explicit bin rules below expand to the right path.
BUILD_DIR ?= test/build

# Pick a target with ZEPHYR_TARGET=<key> (default below). QEMU targets map to
# both a Zephyr board and QEMU machine; hardware targets map to a Zephyr board
# and provide their own execution wrapper.
ZEPHYR_TARGET ?= mps3-an547

ZEPHYR_BOARD_mps2-an385 := mps2/an385
ZEPHYR_QEMU_mps2-an385  := mps2-an385                                # Cortex-M3
ZEPHYR_BOARD_mps2-an386 := mps2/an386
ZEPHYR_QEMU_mps2-an386  := mps2-an386                                # Cortex-M4
ZEPHYR_BOARD_mps2-an500 := mps2/an500
ZEPHYR_QEMU_mps2-an500  := mps2-an500                                # Cortex-M7
ZEPHYR_BOARD_mps2-an521 := mps2/an521/cpu0
ZEPHYR_QEMU_mps2-an521  := mps2-an521                                # Cortex-M33
ZEPHYR_BOARD_mps3-an547 := mps3/corstone300/an547
ZEPHYR_QEMU_mps3-an547  := mps3-an547                                # Cortex-M55
ZEPHYR_BOARD_nucleo-n657x0-q := nucleo_n657x0_q                       # Cortex-M55

ZEPHYR_FIPS202_BACKEND_mps3-an547 := fips202/native/armv81m/mve.h
ZEPHYR_FIPS202_BACKEND_nucleo-n657x0-q := fips202/native/armv81m/mve.h

ZEPHYR_TARGETS := mps2-an385 mps2-an386 mps2-an500 mps2-an521 mps3-an547 nucleo-n657x0-q

ZEPHYR_BOARD := $(ZEPHYR_BOARD_$(ZEPHYR_TARGET))
export QEMU_MACHINE := $(strip $(ZEPHYR_QEMU_$(ZEPHYR_TARGET)))
ZEPHYR_IS_NUCLEO_N657X0_Q := $(filter nucleo-n657x0-q,$(ZEPHYR_TARGET))

ifneq ($(ZEPHYR_IS_NUCLEO_N657X0_Q),)
CROSS_PREFIX ?= arm-none-eabi-
CC = gcc
endif

ifeq ($(ZEPHYR_BOARD),)
$(error Unknown ZEPHYR_TARGET '$(ZEPHYR_TARGET)'. Supported: $(ZEPHYR_TARGETS))
endif

# The test binaries are built by Zephyr's CMake (which uses its own arm
# toolchain via the .#zephyr dev shell), not the generic Make rules. The
# top-level targets still attach the usual object/library prerequisites to the
# bin paths; with OPT=0 those are portable host objects that compile cleanly
# and are simply discarded (the Zephyr ELF is copied over them).
OPT ?= 0

# Native backends are an OPT=1 feature (an547 builds the Armv8.1-M MVE backend).
ZEPHYR_FIPS202_BACKEND := $(if $(filter 1,$(OPT)),$(strip $(ZEPHYR_FIPS202_BACKEND_$(ZEPHYR_TARGET))))

ZEPHYR_APP := $(PLATFORM_PATH)/app
ZEPHYR_BUILD_DIR := $(BUILD_DIR)/zephyr/$(ZEPHYR_TARGET)
ZEPHYR_ACTIVE_TARGET := $(BUILD_DIR)/zephyr/.active-target
ZEPHYR_APP_INPUTS := \
	$(ZEPHYR_APP)/CMakeLists.txt \
	$(ZEPHYR_APP)/Kconfig \
	$(ZEPHYR_APP)/prj.conf \
	$(ZEPHYR_APP)/nucleo_n657x0_q.conf \
	$(ZEPHYR_APP)/shim.c \
	$(ZEPHYR_APP)/shim_nucleo_n657x0_q.c \
	$(ZEPHYR_APP)/nucleo_n657x0_q.overlay
ZEPHYR_NUCLEO_PLATFORM_PATH := test/baremetal/platform/nucleo-n657x0-q
ZEPHYR_NUCLEO_OVERLAY := $(abspath $(ZEPHYR_APP)/nucleo_n657x0_q.overlay)
ZEPHYR_NUCLEO_CONF := $(abspath $(ZEPHYR_APP)/nucleo_n657x0_q.conf)
ZEPHYR_TARGET_CMAKE_ARGS := $(if $(ZEPHYR_IS_NUCLEO_N657X0_Q),\
	-DZEPHYR_NUCLEO_N657X0_Q=ON \
	-DEXTRA_CONF_FILE=$(ZEPHYR_NUCLEO_CONF) \
	-DDTC_OVERLAY_FILE=$(ZEPHYR_NUCLEO_OVERLAY))

.PHONY: zephyr_target_marker_force
$(ZEPHYR_ACTIVE_TARGET): zephyr_target_marker_force
	$(Q)[ -d $(@D) ] || mkdir -p $(@D)
	$(Q)if [ ! -f $@ ] || [ "$$(cat $@)" != "$(ZEPHYR_TARGET)" ]; then \
		echo "$(ZEPHYR_TARGET)" > $@; \
	fi

# Build a test as a Zephyr application and drop the resulting ELF at the path
# the top-level Makefile expects. An explicit rule for the exact bin path wins
# over the generic link pattern rule in test/mk/rules.mk.
#   $(1) level  $(2) bin name  $(3) test source (repo-relative)  $(4) extra -D
define ZEPHYR_BIN
$(BUILD_DIR)/mlkem$(1)/bin/$(2): $(ZEPHYR_ACTIVE_TARGET) $(ZEPHYR_APP_INPUTS) $(3)
	$$(Q)echo "  ZEPHYR  $(ZEPHYR_TARGET) ML-KEM-$(1): $(3)"
	$$(Q)cmake -GNinja -S $(ZEPHYR_APP) -B $(ZEPHYR_BUILD_DIR)/$(2) \
		-DBOARD=$(ZEPHYR_BOARD) \
		-DZEPHYR_NATIVE_ROOT=$(CURDIR) \
		-DZEPHYR_LEVEL=$(1) \
		-DZEPHYR_TEST_SRC=$(3) \
		-DZEPHYR_TEST_DEFS="NTESTS_FUNC=3 NTESTS_KAT=100 MLK_BENCHMARK_NTESTS=10 MLK_BENCHMARK_NITERATIONS=10 MLK_BENCHMARK_NWARMUP=10" \
		-DZEPHYR_FIPS202_BACKEND=$(ZEPHYR_FIPS202_BACKEND) \
		$(if $(ZEPHYR_FIPS202_BACKEND),-DCONFIG_FIPS202_MVE_BACKEND=y) \
		$(ZEPHYR_TARGET_CMAKE_ARGS) \
		$(4) \
		-DUSER_CACHE_DIR=$(abspath $(ZEPHYR_BUILD_DIR)/$(2)/.cache) \
		>/dev/null
	$$(Q)cmake --build $(ZEPHYR_BUILD_DIR)/$(2) >/dev/null
	$$(Q)[ -d $$(@D) ] || mkdir -p $$(@D)
	$$(Q)cp $(ZEPHYR_BUILD_DIR)/$(2)/zephyr/zephyr.elf $$@
endef

$(eval $(call ZEPHYR_BIN,512,test_mlkem512,test/src/test_mlkem.c))
$(eval $(call ZEPHYR_BIN,768,test_mlkem768,test/src/test_mlkem.c))
$(eval $(call ZEPHYR_BIN,1024,test_mlkem1024,test/src/test_mlkem.c))

$(eval $(call ZEPHYR_BIN,512,gen_KAT512,test/src/gen_KAT.c))
$(eval $(call ZEPHYR_BIN,768,gen_KAT768,test/src/gen_KAT.c))
$(eval $(call ZEPHYR_BIN,1024,gen_KAT1024,test/src/gen_KAT.c))

$(eval $(call ZEPHYR_BIN,512,acvp_mlkem512,test/acvp/acvp_mlkem.c))
$(eval $(call ZEPHYR_BIN,768,acvp_mlkem768,test/acvp/acvp_mlkem.c))
$(eval $(call ZEPHYR_BIN,1024,acvp_mlkem1024,test/acvp/acvp_mlkem.c))

$(eval $(call ZEPHYR_BIN,512,wycheproof_mlkem512,test/wycheproof/wycheproof_mlkem.c))
$(eval $(call ZEPHYR_BIN,768,wycheproof_mlkem768,test/wycheproof/wycheproof_mlkem.c))
$(eval $(call ZEPHYR_BIN,1024,wycheproof_mlkem1024,test/wycheproof/wycheproof_mlkem.c))

$(eval $(call ZEPHYR_BIN,512,bench_mlkem512,test/bench/bench_mlkem.c,-DZEPHYR_TEST_HAL=ON))
$(eval $(call ZEPHYR_BIN,768,bench_mlkem768,test/bench/bench_mlkem.c,-DZEPHYR_TEST_HAL=ON))
$(eval $(call ZEPHYR_BIN,1024,bench_mlkem1024,test/bench/bench_mlkem.c,-DZEPHYR_TEST_HAL=ON))

$(eval $(call ZEPHYR_BIN,512,bench_components_mlkem512,test/bench/bench_components_mlkem.c,-DZEPHYR_TEST_HAL=ON))
$(eval $(call ZEPHYR_BIN,768,bench_components_mlkem768,test/bench/bench_components_mlkem.c,-DZEPHYR_TEST_HAL=ON))
$(eval $(call ZEPHYR_BIN,1024,bench_components_mlkem1024,test/bench/bench_components_mlkem.c,-DZEPHYR_TEST_HAL=ON))

ifeq ($(ZEPHYR_IS_NUCLEO_N657X0_Q),)
EXEC_WRAPPER := $(abspath $(PLATFORM_PATH)/exec_wrapper.py)
else
EXEC_WRAPPER := $(abspath $(ZEPHYR_NUCLEO_PLATFORM_PATH)/exec_wrapper.py)

FLEXMEM_CONFIG_ELF ?= $(BUILD_DIR)/nucleo-n657x0-q/flexmem_config.elf
FLEXMEM_CONFIG_LDSCRIPT := $(ZEPHYR_NUCLEO_PLATFORM_PATH)/linker/flexmem_config_default.ld
FLEXMEM_CONFIG_SOURCES := \
    $(ZEPHYR_NUCLEO_PLATFORM_PATH)/src/flexmem_config.c \
    $(NUCLEO_N657X0_Q_PATH)/system_stm32n6xx.c \
    $(ZEPHYR_NUCLEO_PLATFORM_PATH)/src/startup_stm32n657xx.S

FLEXMEM_CONFIG_CFLAGS := \
	-O3 -g \
	-Wall -Wextra -Wshadow \
	-Wno-pedantic \
	-Wno-redundant-decls \
	-Wno-missing-prototypes \
	-fno-common \
	-ffunction-sections \
	-fdata-sections \
	--sysroot=$(SYSROOT) \
	-DDEVICE=nucleo-n657x0-q \
	-DSTM32N657xx \
	-DARMCM55 \
	-DSEMIHOSTING \
	-I$(ZEPHYR_NUCLEO_PLATFORM_PATH)/src \
	-I$(NUCLEO_N657X0_Q_PATH) \
	-I$(NUCLEO_N657X0_Q_PATH)/Drivers/STM32N6xx_HAL_Driver/Inc \
	-I$(NUCLEO_N657X0_Q_PATH)/Drivers/CMSIS/Core/Include \
	-I$(NUCLEO_N657X0_Q_PATH)/Drivers/CMSIS/Core/Include/m-profile \
	-I$(NUCLEO_N657X0_Q_PATH)/Drivers/CMSIS/Device/ST \
	-I$(NUCLEO_N657X0_Q_PATH)/Drivers/CMSIS/Device/ST/STM32N6xx/Include/ \
	-mcmse \
	-march=armv8.1-m.main+mve.fp \
	-mcpu=cortex-m55 \
	-mthumb \
	-mfloat-abi=hard -mfpu=fpv5-sp-d16 \
	-Wno-error -Wno-conversion -Wno-sign-conversion \
	-Wno-unused-parameter -Wno-maybe-uninitialized -Wno-unused-function

.PHONY: flexmem_config run_flexmem_config

ZEPHYR_NUCLEO_N657X0_Q_RUN_TARGETS := \
	run_func run_func_512 run_func_768 run_func_1024 \
	run_kat run_kat_512 run_kat_768 run_kat_1024 \
	run_acvp \
	run_bench run_bench_512 run_bench_768 run_bench_1024 \
	run_bench_components run_bench_components_512 run_bench_components_768 run_bench_components_1024 \
	run_unit run_unit_512 run_unit_768 run_unit_1024 \
	run_alloc run_alloc_512 run_alloc_768 run_alloc_1024 \
	run_rng_fail run_rng_fail_512 run_rng_fail_768 run_rng_fail_1024 \
	run_wycheproof

$(ZEPHYR_NUCLEO_N657X0_Q_RUN_TARGETS): run_flexmem_config

flexmem_config: $(FLEXMEM_CONFIG_ELF)

$(FLEXMEM_CONFIG_ELF): $(FLEXMEM_CONFIG_SOURCES) $(FLEXMEM_CONFIG_LDSCRIPT)
	$(Q)echo "  LD      $@"
	$(Q)[ -d $(@D) ] || mkdir -p $(@D)
	$(Q)$(CC) $(FLEXMEM_CONFIG_CFLAGS) \
		-ffreestanding \
		-Wl,--gc-sections -Wl,--no-warn-rwx-segments \
		--specs=rdimon.specs \
		-T$(FLEXMEM_CONFIG_LDSCRIPT) \
		-o $@ $(FLEXMEM_CONFIG_SOURCES) -lc -lrdimon

run_flexmem_config: flexmem_config
	$(Q)python3 $(ZEPHYR_NUCLEO_PLATFORM_PATH)/flexmem_configure.py $(FLEXMEM_CONFIG_ELF)
endif
