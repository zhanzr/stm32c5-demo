/**
  * @file crt0_clang.c
  * @brief CLANG-only replacement for the broken ST newlib crt0 data init.
  *
  * The ST LLVM toolchain links newlib's `libcrt0-nosys.a`.  Its `_start`/
  * `_mainCRTStartup` zeroes .bss (via memset) but performs the .data copy
  * through two function-pointer hooks that the linker leaves NULL, so the
  * .data section is never copied from flash to RAM.  As a result every
  * statically-initialized global is garbage, which breaks the HAL clock/HSI
  * tick configuration and prevents the firmware from booting under ST LLVM.
  *
  * This file provides a strong `_mainCRTStartup` / `_start` (aliased) that
  * copies .data and zeroes .bss explicitly using the GNU linker symbols,
  * then runs the C library pre-main sequence like the stock crt0.  It is
  * compiled ONLY for the CLANG (ST LLVM) config.
  *
  * Reset_Handler already switched to the stack and called SystemInit() before
  * jumping here, so we only need to finish the C runtime bring-up.
  */
#include <stdint.h>
#include <string.h>
#include <stddef.h>

extern uint32_t _sidata[];          /* .data load address (flash)  */
extern uint32_t __data_start__[];   /* .data VMA (RAM)             */
extern uint32_t __data_end__[];     /* end of .data (RAM)          */
extern uint32_t __bss_start__[];    /* start of .bss (RAM)         */
extern uint32_t __bss_end__[];      /* end of .bss (RAM)           */

/* CLANG-only override of newlib `_sbrk`.
 *
 * The ST newlib `libnosys`/libc `_sbrk` grows the heap all the way up to the
 * `__stack` top-of-stack symbol (0x20001750 here), which OVERLAPS the reserved
 * stack region [__StackLimit, __StackTop].  Once malloc allocates into that
 * region the heap and stack corrupt each other and malloc branches to a
 * garbage RAM address (IACCVIOL).  GCC is fine because its `_sbrk` comes from
 * the DFP sysmem.c and stops at __HeapLimit.  Provide the equivalent limit
 * here so the CLANG heap stops at __HeapLimit (== __StackLimit).
 */
void *_sbrk(ptrdiff_t incr)
{
  extern char __end__;      /* ld: heap start */
  extern char __HeapLimit;  /* ld: heap end / stack limit */
  static char *heap_end;

  if (heap_end == (char *)0)
  {
    heap_end = &__end__;
  }

  if (heap_end + incr > &__HeapLimit)
  {
    return (void *)-1;
  }

  char *prev = heap_end;
  heap_end += incr;
  return (void *)prev;
}

void __libc_init_array(void);
extern int main(void);
extern void exit(int code);

/* Override the ST newlib crt0 data init that is left NULL by the link. */
void _mainCRTStartup(void);

void _start(void) __attribute__((alias("_mainCRTStartup")));

void _mainCRTStartup(void)
{
  /* Copy .data from its load address in flash to RAM. */
  const uint8_t *src = (const uint8_t *)_sidata;
  uint8_t *dst = (uint8_t *)__data_start__;
  uintptr_t n = (uintptr_t)__data_end__ - (uintptr_t)__data_start__;
  while (n--)
  {
    *dst++ = *src++;
  }

  /* Zero .bss. */
  dst = (uint8_t *)__bss_start__;
  n = (uintptr_t)__bss_end__ - (uintptr_t)__bss_start__;
  while (n--)
  {
    *dst++ = 0;
  }

  /* Pre-main: run global constructors / init array, then main. */
  __libc_init_array();
  main();

  exit(0);
}