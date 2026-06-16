/*
 * Copyright (c) The mlkem-native project authors
 * SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT
 */

.syntax unified
.fpu fpv5-sp-d16
.thumb

.global g_pfnVectors
.global Reset_Handler

.extern _estack
.extern _sidata
.extern _sdata
.extern _edata
.extern _sbss
.extern _ebss
.extern __StackLimit
.extern SystemInit
.extern __libc_init_array
.extern main
.extern _exit

.section .isr_vector,"a",%progbits
.type g_pfnVectors, %object
g_pfnVectors:
  .word _estack
  .word Reset_Handler
  .word NMI_Handler
  .word HardFault_Handler
  .word MemManage_Handler
  .word BusFault_Handler
  .word UsageFault_Handler
  .word SecureFault_Handler
  .word 0
  .word 0
  .word 0
  .word SVC_Handler
  .word DebugMon_Handler
  .word 0
  .word PendSV_Handler
  .word SysTick_Handler
  .rept 128
  .word Default_Handler
  .endr
.size g_pfnVectors, . - g_pfnVectors

.section .text.Reset_Handler,"ax",%progbits
.type Reset_Handler, %function
.thumb_func
Reset_Handler:
  cpsid i
  ldr r0, =_estack
  msr msp, r0
  ldr r0, =__StackLimit
  msr msplim, r0
  msr psplim, r0
  isb

  ldr r0, =_sidata
  ldr r1, =_sdata
  ldr r2, =_edata
1:
  cmp r1, r2
  bcc 2f
  b 3f
2:
  ldr r3, [r0], #4
  str r3, [r1], #4
  b 1b

3:
  ldr r1, =_sbss
  ldr r2, =_ebss
  movs r0, #0
4:
  cmp r1, r2
  bcc 5f
  b 6f
5:
  str r0, [r1], #4
  b 4b

6:
  bl SystemInit
  bl __libc_init_array
  movs r0, #0
  movs r1, #0
  bl main
  bl _exit
7:
  b 7b
.size Reset_Handler, . - Reset_Handler

.section .text.Default_Handler,"ax",%progbits
.type Default_Handler, %function
.thumb_func
Default_Handler:
  b Default_Handler
.size Default_Handler, . - Default_Handler

.macro weak_handler name
  .weak \name
  .set \name, Default_Handler
.endm

weak_handler NMI_Handler
weak_handler HardFault_Handler
weak_handler MemManage_Handler
weak_handler BusFault_Handler
weak_handler UsageFault_Handler
weak_handler SecureFault_Handler
weak_handler SVC_Handler
weak_handler DebugMon_Handler
weak_handler PendSV_Handler
weak_handler SysTick_Handler
