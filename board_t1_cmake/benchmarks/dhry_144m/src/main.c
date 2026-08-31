#include <stdio.h>
#include "main.h"
#include "custom_def.h"
#include "dhry.h"

int main(void)
{
  if (mx_system_init() != SYSTEM_OK)
  {
    return (-1);
  }

  const uint32_t cpu_hz = SystemCoreClock;

  printf("\r\n=== Dhrystone 2.1 on STM32C542RCT6 @ %lu Hz ===\r\n",
         (unsigned long)cpu_hz);

  while (1)
  {
    dhry_main(cpu_hz);
    printf("\r\nCPU freq: %lu Hz (%lu MHz)\r\n",
           (unsigned long)cpu_hz, (unsigned long)(cpu_hz / 1000000UL));
    printf("Compiler: %s %s\r\n", COMPILER_NAME, COMPILER_FLAGS);
    HAL_Delay(10000);
  }

  return 0;
}
