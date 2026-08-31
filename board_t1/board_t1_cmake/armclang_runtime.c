/**
  * @file armclang_runtime.c
  * @brief Minimal ST LLVM / newlib runtime shim used by the ARMCLANG config.
  *
  * The STMicroelectronics LLVM/clang toolchain defaults to the picolibc C
  * runtime, but the CMSIS-generated startup (startup_stm32c542xx.c) and this
  * project are written for newlib.  The linker script stm32c542xc_flash.ld
  * supplies the stack/stack-limit symbols that the CMSIS startup programs into
  * MSPLIM / PSPLIM (__stack, __stack_limit).  This file supplies the one extra
  * symbol the ST newlib runtimes do not provide for single-threaded cortex-M33
  * bare-metal so the firmware links against newlib (libcrt0-nosys + libc +
  * libnosys) instead of picolibc.
  *
  * Only compiled when COMPILER_FAMILY == "CLANG" (see cmake/files.cmake).
  */
#include <stdint.h>

/* newlib's thread-local errno/reentrancy calls __aeabi_read_tp() to fetch the
 * per-thread TLS base.  This firmware is single threaded, so returning a
 * fixed, aligned, non-NULL buffer is sufficient.  (Kept live even though
 * --gc-sections may drop it if newlib never calls it here.) */
static uint8_t __aeabi_tp_buf[64] __attribute__((aligned(8)));

void *__aeabi_read_tp(void)
{
  return (void *)__aeabi_tp_buf;
}
