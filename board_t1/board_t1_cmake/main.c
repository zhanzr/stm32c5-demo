/**
  ******************************************************************************
  * file           : main.c
  * brief          : Main program body
  *                  Calls target system initialization then loop in main.
  ******************************************************************************
  *
  * Copyright (c) 2025 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "adc_internal.h"

/* Private typedef -----------------------------------------------------------*/
/* Private define ------------------------------------------------------------*/
/* Private macro -------------------------------------------------------------*/
/* Private variables ---------------------------------------------------------*/
/* Private functions prototype -----------------------------------------------*/
#include <stdio.h>

/**
  * brief:  The application entry point.
  * retval: none but we specify int to comply with C99 standard
  */
int main(void)
{
  /** System Init: this code placed in targets folder initializes your system.
    * It calls the initialization (and sets the initial configuration) of the peripherals.
    * You can use STM32CubeMX to generate and call this code or not in this project.
    * It also contains the HAL initialization and the initial clock configuration.
    */
  if (mx_system_init() != SYSTEM_OK)
  {
    return (-1);
  }
  else
  {
    /*
      * You can start your application code here
      */
    uint32_t tick = 0;

    if (adc_internal_init() != 0)
    {
      printf("ADC internal channels init failed\n");
    }

    while (1) {
      HAL_Delay(100);
      tick++;

      /* Toggle LD1 (PA5, low-active) every 500 ms */
      if ((tick % 5U) == 0U)
      {
        HAL_GPIO_TogglePin(LD1_PORT, LD1_PIN);
      }

      /* Print system clock and the ADC internal channels every 5 seconds */
      if ((tick % 50U) == 0U)
      {
        adc_internal_sample_t adc_smpl;

        printf("SystemCoreClock = %u Hz\n", (unsigned int)SystemCoreClock);
        if (adc_internal_sample(&adc_smpl) == 0)
        {
          printf("ADC internal: Vdda %d mV, VREFINT %d mV, die temp %d.%02d C\n",
                 (int)adc_smpl.vref_mv,
                 (int)adc_smpl.vrefint_mv,
                 (int)(adc_smpl.temp_mdegc / 1000),
                 (int)((adc_smpl.temp_mdegc % 1000) / 10));
        }
        else
        {
          printf("ADC internal sampling failed\n");
        }
      }
    }
  }
} /* end main */

