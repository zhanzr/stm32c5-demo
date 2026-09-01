/**
  * @file adc_internal.c
  * @brief Sampling of the STM32C5 internal ADC channels on ADC1.
  *
  * Channel switching between reads is done through the LL layer directly:
  * the HAL wrapper HAL_ADC_SetConfigChannel() rejects calls while the ADC is
  * ACTIVE, but the per-channel sampling time and internal-channel path are
  * configured once here at init time, so only the sequencer rank (which
  * channel is converted on rank 1) has to change between samples.
  */
#include "adc_internal.h"

#include "mx_adc1.h"
#include "stm32c5xx_hal_adc.h"
#include "stm32c5xx_ll_adc.h"

/* ------------------------------------------------------------------ */
/* Module state                                                        */
/* ------------------------------------------------------------------ */
static hal_adc_handle_t *s_hadc;

/* ------------------------------------------------------------------ */
/* Temperature helper (millidegree, factory-calibrated values)         */
/* ------------------------------------------------------------------ */
static int32_t calc_temp_mdegc(int32_t ts_raw, int32_t vref_mv)
{
  int32_t cal1 = (int32_t)*LL_ADC_TEMPSENSOR_CAL1_ADDR;
  int32_t cal2 = (int32_t)*LL_ADC_TEMPSENSOR_CAL2_ADDR;
  int32_t slope = cal2 - cal1;
  int32_t ts_scaled;

  if (slope == 0)
  {
    return (int32_t)LL_ADC_TEMPERATURE_CALC_ERROR;
  }

  /* Scale the raw data to the calibration reference voltage, like
     LL_ADC_CALC_TEMPERATURE(), then interpolate between CAL1 (30 C) and
     CAL2 (140 C) with 1000x temperature gain for mdegC resolution. */
  ts_scaled = (ts_raw * vref_mv) / (int32_t)LL_ADC_TEMPSENSOR_CAL_VREF;

  return (((ts_scaled - cal1) * 1000L
           * (int32_t)(LL_ADC_TEMPSENSOR_CAL2_TEMP - LL_ADC_TEMPSENSOR_CAL1_TEMP))
          / slope)
         + (int32_t)LL_ADC_TEMPSENSOR_CAL1_TEMP * 1000L;
}

/* ------------------------------------------------------------------ */
/* Single-shot read of one channel                                     */
/* ------------------------------------------------------------------ */
static int adc_read_channel(hal_adc_channel_t channel, int32_t *raw)
{
  ADC_TypeDef *p_instance;

  if (s_hadc == NULL)
  {
    return -1;
  }
  p_instance = (ADC_TypeDef *)s_hadc->instance;

  /* Select the channel as the regular rank-1 (only) conversion.  Sampling
     time and internal path were already set up for both channels at init. */
  LL_ADC_REG_SetSequencerRanks(p_instance, LL_ADC_REG_RANK_1, (uint32_t)channel);

  if (HAL_ADC_REG_StartConv(s_hadc) != HAL_OK)
  {
    return -2;
  }
  if (HAL_ADC_REG_PollForConv(s_hadc, 100U) != HAL_OK)
  {
    return -3;
  }
  if (raw != NULL)
  {
    *raw = HAL_ADC_REG_ReadConversionData(s_hadc);
  }
  return 0;
}

/* ------------------------------------------------------------------ */
/* Public API                                                          */
/* ------------------------------------------------------------------ */
int adc_internal_init(void)
{
  hal_adc_channel_config_t cfg;

  s_hadc = mx_adc1_gethandle();
  if (s_hadc == NULL)
  {
    return -1;
  }

  cfg.group = HAL_ADC_GROUP_REGULAR;
  cfg.sequencer_rank = 1;
  cfg.sampling_time = HAL_ADC_SAMPLING_TIME_289CYCLES;   /* longest available */
  cfg.input_mode = HAL_ADC_IN_SINGLE_ENDED;

  /* The longest sampling time on this C5 part is 289 ADC clock cycles.  For
     the internal references it stays above the minimum required sampling
     time at the configured ADC kernel clock.  Registering both channels here
     also lets HAL_ADC_Start() wait for the internal-channel stabilization. */
  if (HAL_ADC_SetConfigChannel(s_hadc, HAL_ADC_CHANNEL_TEMPSENSOR, &cfg) != HAL_OK)
  {
    return -2;
  }
  if (HAL_ADC_SetConfigChannel(s_hadc, HAL_ADC_CHANNEL_VREFINT, &cfg) != HAL_OK)
  {
    return -3;
  }

  if (HAL_ADC_Start(s_hadc) != HAL_OK)
  {
    return -4;
  }
  if (HAL_ADC_Calibrate(s_hadc) != HAL_OK)
  {
    return -5;
  }

  return 0;
}

int adc_internal_sample(adc_internal_sample_t *s)
{
  int32_t raw;
  uint32_t vref_mv;

  if (s == NULL)
  {
    return -1;
  }

  /* VREFINT first: raw internal reference voltage, plus the real Vref+ used
     by all the conversions below (no assumption of a nominal 3.3 V Vdda). */
  if (adc_read_channel(HAL_ADC_CHANNEL_VREFINT, &raw) != 0)
  {
    return -2;
  }
  vref_mv = LL_ADC_CALC_VREFANALOG_VOLTAGE((uint32_t)raw, LL_ADC_RESOLUTION_12B);
  s->vref_mv = (int32_t)vref_mv;
  s->vrefint_mv = LL_ADC_CALC_DATA_TO_VOLTAGE(vref_mv, raw, LL_ADC_RESOLUTION_12B);

  /* Die temperature sensor */
  if (adc_read_channel(HAL_ADC_CHANNEL_TEMPSENSOR, &raw) != 0)
  {
    return -3;
  }
  s->temp_mdegc = calc_temp_mdegc(raw, (int32_t)vref_mv);
  if (s->temp_mdegc == (int32_t)LL_ADC_TEMPERATURE_CALC_ERROR)
  {
    return -4;
  }

  return 0;
}