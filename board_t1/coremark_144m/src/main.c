#include <stdint.h>
#include <stdio.h>

#include "main.h"
#include "core_portme.h"

int coremark_main(void);

int main(void)
{
  if (mx_system_init() != SYSTEM_OK)
  {
    return (-1);
  }

  const uint32_t cpu_hz = SystemCoreClock;

  while (1)
  {
    printf("\r\n--- CoreMark run on STM32C542RCT6 @ %lu Hz ---\r\n",
           (unsigned long)cpu_hz);
    coremark_main();
    printf("--- CoreMark complete. %lu Hz, %s ---\r\n",
           (unsigned long)cpu_hz, COMPILER_FLAGS);
    for (int i = 0; i < 10; i++)
    {
      HAL_Delay(1000);
    }
  }

  return 0;
}