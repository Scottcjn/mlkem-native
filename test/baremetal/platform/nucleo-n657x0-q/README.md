<!--
Copyright (c) The mldsa-native project authors
Copyright (c) The mlkem-native project authors
Copyright (c) Arm Ltd.
SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT
-->

# NUCLEO-N657X0-Q Zephyr Hardware Helpers

This directory contains only the NUCLEO-N657X0-Q host/debug helpers still used
by the Zephyr test path. The test ELFs are built by `test/zephyr/platform.mk`;
this directory provides the RAM-loaded FLEXMEM configurator and the OpenOCD/GDB
wrapper used to run Zephyr ELFs on hardware.

The board is never flashed. CI first loads `flexmem_config.elf` into RAM to
expand the STM32N657X0 ITCM/DTCM layout, resets the target so the layout
latches, then loads the Zephyr test ELF into RAM through GDB.

## Files Kept Here

- `flexmem_configure.py`: downloads and runs `flexmem_config.elf`, then polls
  `SYSCFG->CM55TCMCR` until the requested layout is visible.
- `exec_wrapper.py`: starts OpenOCD, loads a Zephyr ELF with GDB, restores the
  packed argv blob at `__wrap_main`, dumps the RAM stdout capture buffer, and
  maps target sentinels to host exit codes.
- `nucleo_host/`: shared Python helpers for argv packing, OpenOCD commands, GDB
  script generation, symbol lookup, result parsing, and user-facing FLEXMEM
  build hints.
- `src/flexmem_config.c`, `src/startup_stm32n657xx.S`, and
  `linker/flexmem_config_default.ld`: the minimal RAM-resident FLEXMEM config
  image built by the Zephyr makefile.
- `test_nucleo_host.py`: host-only regression tests for the Python helpers.

The old baremetal test linker script, command-line shim, semihosting syscall
capture, HAL clock setup, and standalone run shim have been removed because the
Zephyr application now provides that runtime support in `test/zephyr/app`.

## Build and Run

Use the Zephyr platform makefile and select the NUCLEO target:

```sh
nix develop .#zephyr
make flexmem_config EXTRA_MAKEFILE=test/zephyr/platform.mk ZEPHYR_TARGET=nucleo-n657x0-q
make run_func_512 EXTRA_MAKEFILE=test/zephyr/platform.mk ZEPHYR_TARGET=nucleo-n657x0-q
```

`run_*` targets for `ZEPHYR_TARGET=nucleo-n657x0-q` depend on
`run_flexmem_config`, so the board layout is restored before each RAM-loaded
Zephyr test image.

Useful environment variables:

```sh
export OPENOCD_SPEED=8000
export OPENOCD_SERIAL=<optional-probe-serial>
export GDB_PORT=3333
```

`OPENOCD`, `OPENOCD_INTERFACE`, `OPENOCD_TARGET`, `OPENOCD_TRANSPORT`, `GDB`,
`NM`, and `READELF` can override the default tools and OpenOCD scripts.

## FLEXMEM Sequence

STM32N657X0 starts with 64 KiB ITCM and 128 KiB DTCM. Tests use a two-binary
RAM-only sequence to expand both regions to 256 KiB:

1. `flexmem_configure.py` resolves `main` and `_estack` in
   `flexmem_config.elf`.
2. OpenOCD connects with `reset_config srst_only srst_nogate
   connect_assert_srst`, loads the config ELF into the reset-time RAM layout,
   sets `MSP=<_estack>` and `PC=<main|1>`, and resumes it.
3. The helper polls `SYSCFG->CM55TCMCR` at `0x56008008` until
   `(value & 0xff) == 0x99`.
4. OpenOCD switches to `reset_config none` and runs `reset run` so the expanded
   layout is applied before the Zephyr ELF is loaded.
5. `exec_wrapper.py` starts a fresh OpenOCD runtime GDB server, GDB-loads the
   Zephyr ELF, breaks at `__wrap_main`, restores argv, continues the test, and
   harvests target stdout from RAM.

If a GDB `load` fails before target output starts, or the target enters a
HardFault, the wrapper can rerun FLEXMEM configuration and retry according to
`GDB_LOAD_FAILURE_RECOVERY_ATTEMPTS` and `GDB_HARDFAULT_RECOVERY_ATTEMPTS`.
