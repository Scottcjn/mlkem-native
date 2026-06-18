/*
 * Copyright (c) The mlkem-native project authors
 * SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT
 */

/*
 * Zephyr entrypoint shim for RAM-loaded NUCLEO-N657X0-Q tests.
 *
 * The OpenOCD/GDB wrapper breaks at __wrap_main after Zephyr has cleared BSS,
 * restores a packed argv block into mlk_cmdline_block, then continues here.
 * Target stdout is captured in RAM and dumped by the host wrapper after the
 * final breakpoint.
 */

#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <zephyr/kernel.h>

extern int mlk_test_main(int argc, char **argv);

typedef struct cmdline_s
{
  int argc;
  char *argv[];
} cmdline_t;

#define CMDLINE_BLOCK_SIZE (64U * 1024U)
#define NUCLEO_STDOUT_CAPTURE_SIZE (1280U * 1024U)
#define NUCLEO_CMDLINE_ADDR 0x340B0000U
#define NUCLEO_STDOUT_CAPTURE_ADDR 0x340C0000U

__asm__(
    ".global mlk_cmdline_block\n"
    ".set mlk_cmdline_block, 0x340b0000\n"
    ".global nucleo_stdout_capture\n"
    ".set nucleo_stdout_capture, 0x340c0000\n");

extern unsigned char mlk_cmdline_block[CMDLINE_BLOCK_SIZE];
extern volatile uint8_t nucleo_stdout_capture[NUCLEO_STDOUT_CAPTURE_SIZE];

__attribute__((used)) volatile uint32_t nucleo_stdout_capture_len;
__attribute__((used)) volatile uint32_t nucleo_stdout_capture_truncated;

static void capture_write(const char *src, size_t length)
{
  uint32_t offset = nucleo_stdout_capture_len;

  if (offset < NUCLEO_STDOUT_CAPTURE_SIZE)
  {
    uint32_t available = NUCLEO_STDOUT_CAPTURE_SIZE - offset;
    uint32_t written = (length > available) ? available : (uint32_t)length;

    for (uint32_t idx = 0; idx < written; idx++)
    {
      nucleo_stdout_capture[offset + idx] = (uint8_t)src[idx];
    }
    nucleo_stdout_capture_len = offset + written;
    if (written != length)
    {
      nucleo_stdout_capture_truncated = 1;
    }
  }
  else if (length != 0U)
  {
    nucleo_stdout_capture_truncated = 1;
  }
}

static int capture_vprintf(const char *format, va_list ap)
{
  char buf[512];
  int rc = vsnprintf(buf, sizeof(buf), format, ap);

  if (rc < 0)
  {
    return rc;
  }

  capture_write(buf, (size_t)((rc < (int)sizeof(buf)) ? rc : (int)sizeof(buf) - 1));
  if (rc >= (int)sizeof(buf))
  {
    nucleo_stdout_capture_truncated = 1;
  }
  return rc;
}

int __wrap_printf(const char *format, ...)
{
  va_list ap;
  int rc;

  va_start(ap, format);
  rc = capture_vprintf(format, ap);
  va_end(ap);
  return rc;
}

int __wrap_fprintf(FILE *stream, const char *format, ...)
{
  va_list ap;
  int rc;

  (void)stream;
  va_start(ap, format);
  rc = capture_vprintf(format, ap);
  va_end(ap);
  return rc;
}

int __wrap_puts(const char *s)
{
  size_t len = 0;

  while (s[len] != '\0')
  {
    len++;
  }
  capture_write(s, len);
  capture_write("\n", 1);
  return (int)len + 1;
}

int __wrap_putchar(int c)
{
  char ch = (char)c;

  capture_write(&ch, 1);
  return c;
}

int __wrap_fflush(FILE *stream)
{
  (void)stream;
  return 0;
}

__attribute__((noreturn)) static void exit_with_rc(int rc)
{
  if (rc == 0)
  {
    __wrap_printf("[[MLKEM-EXIT:0]]\n");
  }
  else
  {
    __wrap_printf("[[MLKEM-EXIT:1]]\n");
  }

  __asm__ volatile("dsb sy\nisb\nbkpt 0" ::: "memory");
  for (;;)
  {
    k_sleep(K_FOREVER);
  }
}

void __wrap_exit(int status) { exit_with_rc(status); }

__attribute__((noinline, used)) void nucleo_layout_fail(uint32_t code)
{
  (void)code;
  __asm__ volatile("bkpt 0" ::: "memory");
  for (;;)
  {
    k_sleep(K_FOREVER);
  }
}

__attribute__((noinline, used)) void __wrap_main(void)
{
  cmdline_t *cmdline = (cmdline_t *)mlk_cmdline_block;
  int rc = mlk_test_main(cmdline->argc, cmdline->argv);

  exit_with_rc(rc);
}

int main(void)
{
  __wrap_main();
  return 0;
}
