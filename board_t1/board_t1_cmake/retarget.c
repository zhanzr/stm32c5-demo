/**
  ******************************************************************************
  * file           : retarget.c
  * brief          : Retarget __io_putchar to USART2 for printf output.
  ******************************************************************************
  */
#include "mx_usart2.h"

int __io_putchar(int ch)
{
  hal_uart_handle_t *huart = mx_usart2_uart_gethandle();
  HAL_UART_Transmit(huart, (const void *)&ch, 1U, HAL_MAX_DELAY);
  return ch;
}

int _write(int file, char *ptr, int len)
{
  (void)file;
  hal_uart_handle_t *huart = mx_usart2_uart_gethandle();
  HAL_UART_Transmit(huart, (const void *)ptr, (uint32_t)len, HAL_MAX_DELAY);
  return len;
}
