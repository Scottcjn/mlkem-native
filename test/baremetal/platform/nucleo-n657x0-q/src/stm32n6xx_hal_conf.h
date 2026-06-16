/*
 * Copyright (c) The mlkem-native project authors
 * SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT
 */

#ifndef STM32N6XX_HAL_CONF_H
#define STM32N6XX_HAL_CONF_H

#ifdef __cplusplus
extern "C"
{
#endif

#define HAL_MODULE_ENABLED
#define HAL_RCC_MODULE_ENABLED
#define HAL_PWR_MODULE_ENABLED
#define HAL_CORTEX_MODULE_ENABLED

#if !defined(HSE_VALUE)
#define HSE_VALUE 48000000UL
#endif

#if !defined(HSE_STARTUP_TIMEOUT)
#define HSE_STARTUP_TIMEOUT 100UL
#endif

#if !defined(LSE_VALUE)
#define LSE_VALUE 32768UL
#endif

#if !defined(LSE_STARTUP_TIMEOUT)
#define LSE_STARTUP_TIMEOUT 5000UL
#endif

#if !defined(MSI_VALUE)
#define MSI_VALUE 4000000UL
#endif

#if !defined(HSI_VALUE)
#define HSI_VALUE 64000000UL
#endif

#if !defined(LSI_VALUE)
#define LSI_VALUE 32000UL
#endif

#define VDD_VALUE 3300UL
#define TICK_INT_PRIORITY 15U
#define USE_RTOS 0U

#ifdef HAL_RCC_MODULE_ENABLED
#include "stm32n6xx_hal_rcc.h"
#endif

#ifdef HAL_PWR_MODULE_ENABLED
#include "stm32n6xx_hal_pwr.h"
#endif

#ifdef HAL_CORTEX_MODULE_ENABLED
#include "stm32n6xx_hal_cortex.h"
#endif

#ifdef USE_FULL_ASSERT
#define assert_param(expr) \
  ((expr) ? (void)0U : assert_failed((uint8_t *)__FILE__, __LINE__))
void assert_failed(uint8_t *file, uint32_t line);
#else
#define assert_param(expr) ((void)0U)
#endif

#ifdef __cplusplus
}
#endif

#endif /* !STM32N6XX_HAL_CONF_H */
