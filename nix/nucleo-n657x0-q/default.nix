# Copyright (c) The mldsa-native project authors
# Copyright (c) The mlkem-native project authors
# SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

{ stdenvNoCC
, writeText
, zephyr
}:

# Construct a minimal Zephyr/hal_stm32-based platform environment for building
# nucleo-n657x0-q benchmarks. The package copies the CMSIS and STM32 HAL files
# needed by the RAM-loaded bare-metal test flow; startup and board clock setup
# live in the local platform sources.
stdenvNoCC.mkDerivation {
  pname = "mlkem-native-nucleo-n657x0-q";
  version = "zephyr-${zephyr.version or "unknown"}";

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    set -eu

    outp="$out/platform/nucleo-n657x0-q/src/platform"
    cmsis_core="${zephyr}/cmsis_6/CMSIS/Core/Include"
    hal_stm32="${zephyr}/hal_stm32/stm32cube/stm32n6xx"
    hal="$hal_stm32/drivers"
    cmsis_device="$hal_stm32/soc"

    install_file() {
      src_file="$1"
      dst_file="$outp/$2"
      mkdir -p "$(dirname "$dst_file")"
      cp "$src_file" "$dst_file"
    }

    # CMSIS headers reached by stm32n657xx.h/core_cm55.h under the GCC build.
    for header in \
      cmsis_compiler.h \
      cmsis_gcc.h \
      cmsis_version.h \
      core_cm55.h \
      m-profile/armv7m_cachel1.h \
      m-profile/armv8m_mpu.h \
      m-profile/armv8m_pmu.h \
      m-profile/cmsis_gcc_m.h
    do
      install_file "$cmsis_core/$header" "Drivers/CMSIS/Core/Include/$header"
    done

    for header in \
      stm32n6xx.h \
      stm32n657xx.h \
      system_stm32n6xx.h
    do
      install_file "$cmsis_device/$header" "Drivers/CMSIS/Device/ST/STM32N6xx/Include/$header"
    done

    install_file "$cmsis_device/system_stm32n6xx_fsbl.c" "system_stm32n6xx.c"

    mkdir -p "$outp/Drivers/STM32N6xx_HAL_Driver/Inc"
    cp -R "$hal/include/." "$outp/Drivers/STM32N6xx_HAL_Driver/Inc/"

    mkdir -p "$outp/Drivers/STM32N6xx_HAL_Driver/Src"
    for source in \
      stm32n6xx_hal.c \
      stm32n6xx_hal_cortex.c \
      stm32n6xx_hal_pwr.c \
      stm32n6xx_hal_pwr_ex.c \
      stm32n6xx_hal_rcc.c \
      stm32n6xx_hal_rcc_ex.c
    do
      install_file "$hal/src/$source" "Drivers/STM32N6xx_HAL_Driver/Src/$source"
    done
  '';

  setupHook = writeText "setup-hook.sh" ''
    export NUCLEO_N657X0_Q_PATH="$1/platform/nucleo-n657x0-q/src/platform/"
  '';

  meta = {
    description = "Zephyr/hal_stm32 platform files for STM32 NUCLEO-N657X0-Q RAM-only OpenOCD tests";
    homepage = "https://www.zephyrproject.org/";
  };
}
