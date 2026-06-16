/*
 * Copyright (c) The mlkem-native project authors
 * SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT
 */

#include "stm32n6xx.h"
#include "stm32n6xx_hal.h"
#include "stm32n6xx_ll_bus.h"
#include "stm32n6xx_ll_pwr.h"
#include "stm32n6xx_ll_rcc.h"

#define NUCLEO_SYSCLK_HZ 400000000UL
#define NUCLEO_CPUCLK_HZ 800000000UL

static void switch_to_hsi(void)
{
  if (LL_RCC_HSI_IsReady() != 1U)
  {
    LL_RCC_HSI_Enable();
    while (LL_RCC_HSI_IsReady() != 1U)
    {
    }
  }

  LL_RCC_SetSysClkSource(LL_RCC_SYS_CLKSOURCE_HSI);
  while (LL_RCC_GetSysClkSource() != LL_RCC_SYS_CLKSOURCE_STATUS_HSI)
  {
  }

  LL_RCC_SetCpuClkSource(LL_RCC_CPU_CLKSOURCE_HSI);
  while (LL_RCC_GetCpuClkSource() != LL_RCC_CPU_CLKSOURCE_STATUS_HSI)
  {
  }
}

static void setup_fixed_clock_sources(void)
{
  LL_RCC_HSE_DisableBypass();
  LL_RCC_HSE_SelectHSEDiv2AsDiv2Clock();
  LL_RCC_HSE_Enable();
  while (LL_RCC_HSE_IsReady() != 1U)
  {
  }

  LL_RCC_HSI_Enable();
  while (LL_RCC_HSI_IsReady() != 1U)
  {
  }
  LL_RCC_HSI_SetDivider(LL_RCC_HSI_DIV_1);
}

static void setup_pll1(void)
{
  switch_to_hsi();

  LL_RCC_PLL1_Disable();
  LL_RCC_PLL1_SetSource(LL_RCC_PLLSOURCE_HSE);
  LL_RCC_PLL1_DisableModulationSpreadSpectrum();
  if (LL_RCC_PLL1_IsEnabledBypass())
  {
    LL_RCC_PLL1_DisableBypass();
  }
  LL_RCC_PLL1_SetM(3U);
  LL_RCC_PLL1_SetN(150U);
  LL_RCC_PLL1_SetP1(1U);
  LL_RCC_PLL1_SetP2(1U);
  LL_RCC_PLL1_SetFRACN(0U);
  LL_RCC_PLL1_DisableFractionalModulationSpreadSpectrum();
  LL_RCC_PLL1_AssertModulationSpreadSpectrumReset();
  if (!LL_RCC_PLL1P_IsEnabled())
  {
    LL_RCC_PLL1P_Enable();
  }
  LL_RCC_PLL1_Enable();
  while (LL_RCC_PLL1_IsReady() != 1U)
  {
  }
}

static void setup_pll3(void)
{
  LL_RCC_PLL3_Disable();
  LL_RCC_PLL3_SetSource(LL_RCC_PLLSOURCE_HSE);
  LL_RCC_PLL3_DisableModulationSpreadSpectrum();
  if (LL_RCC_PLL3_IsEnabledBypass())
  {
    LL_RCC_PLL3_DisableBypass();
  }
  LL_RCC_PLL3_SetM(3U);
  LL_RCC_PLL3_SetN(125U);
  LL_RCC_PLL3_SetP1(1U);
  LL_RCC_PLL3_SetP2(1U);
  LL_RCC_PLL3_SetFRACN(0U);
  LL_RCC_PLL3_DisableFractionalModulationSpreadSpectrum();
  LL_RCC_PLL3_AssertModulationSpreadSpectrumReset();
  if (!LL_RCC_PLL3P_IsEnabled())
  {
    LL_RCC_PLL3P_Enable();
  }
  LL_RCC_PLL3_Enable();
  while (LL_RCC_PLL3_IsReady() != 1U)
  {
  }
}

static void setup_intermediate_clocks(void)
{
  LL_RCC_IC1_SetSource(LL_RCC_ICCLKSOURCE_PLL1);
  LL_RCC_IC1_SetDivider(3U);
  LL_RCC_IC1_Enable();

  LL_RCC_IC2_SetSource(LL_RCC_ICCLKSOURCE_PLL1);
  LL_RCC_IC2_SetDivider(6U);
  LL_RCC_IC2_Enable();

  LL_RCC_IC6_SetSource(LL_RCC_ICCLKSOURCE_PLL3);
  LL_RCC_IC6_SetDivider(2U);
  LL_RCC_IC6_Enable();

  LL_RCC_IC11_SetSource(LL_RCC_ICCLKSOURCE_PLL1);
  LL_RCC_IC11_SetDivider(3U);
  LL_RCC_IC11_Enable();

  LL_RCC_IC17_SetSource(LL_RCC_ICCLKSOURCE_PLL1);
  LL_RCC_IC17_SetDivider(4U);
  LL_RCC_IC17_Enable();

  LL_RCC_IC18_SetSource(LL_RCC_ICCLKSOURCE_PLL1);
  LL_RCC_IC18_SetDivider(60U);
  LL_RCC_IC18_Enable();
}

void SystemClock_Config(void)
{
  uint32_t misc_ram = LL_MEM_AXISRAM1 | LL_MEM_AXISRAM2 | LL_MEM_AHBSRAM1 |
                      LL_MEM_AHBSRAM2 | LL_MEM_BKPSRAM | LL_MEM_FLEXRAM |
                      LL_MEM_CACHEAXIRAM | LL_MEM_VENCRAM;

  LL_MEM_EnableClock(misc_ram);
  LL_MEM_EnableClockLowPower(misc_ram);

  LL_AHB4_GRP1_EnableClock(LL_AHB4_GRP1_PERIPH_PWR);
  LL_PWR_SetRegulVoltageScaling(LL_PWR_REGU_VOLTAGE_SCALE0);
  LL_PWR_EnableVddIO2();
  LL_PWR_EnableVddIO3();
  LL_PWR_EnableVddIO4();
  LL_PWR_EnableVddIO5();

  setup_fixed_clock_sources();
  setup_pll1();
  setup_pll3();

  LL_RCC_SetAHBPrescaler(LL_RCC_AHB_DIV_2);
  LL_RCC_SetAPB1Prescaler(LL_RCC_APB1_DIV_1);
  LL_RCC_SetAPB2Prescaler(LL_RCC_APB2_DIV_1);
  LL_RCC_SetAPB4Prescaler(LL_RCC_APB4_DIV_1);
  LL_RCC_SetAPB5Prescaler(LL_RCC_APB5_DIV_1);
  LL_RCC_SetTIMPrescaler(LL_RCC_TIM_PRESCALER_2);

  LL_MISC_EnableClock(LL_PER);
  LL_MISC_EnableClockLowPower(LL_PER);
  while (LL_MISC_IsEnabledClock(LL_PER) != 1U)
  {
  }

  setup_intermediate_clocks();

  LL_RCC_SetSysClkSource(LL_RCC_SYS_CLKSOURCE_IC2_IC6_IC11);
  while (LL_RCC_GetSysClkSource() != LL_RCC_SYS_CLKSOURCE_STATUS_IC2_IC6_IC11)
  {
  }

  LL_RCC_SetCpuClkSource(LL_RCC_CPU_CLKSOURCE_IC1);
  while (LL_RCC_GetCpuClkSource() != LL_RCC_CPU_CLKSOURCE_STATUS_IC1)
  {
  }

  SystemCoreClock = NUCLEO_CPUCLK_HZ;
  (void)NUCLEO_SYSCLK_HZ;
}
