/**
  * @file adc_internal.h
  * @brief Sampling of the STM32C5 internal ADC channels (VREFINT, temperature
  *        sensor) on ADC1.
  *
  * The STM32C5 has two internal ADC1 channels:
  *   - the internal voltage reference (VREFINT)        -> raw voltage in mV
  *   - the die temperature sensor (TEMPSENSOR)        -> degrees Celsius
  *
  * All samples are single-shot blockings conversions.  A VREFINT sample is
  * taken alongside the temperature read so the real analog reference voltage
  * (Vref+ / Vdda, factory-calibrated) is used in the conversions instead of
  * assuming a nominal 3.3 V.
  */
#ifndef ADC_INTERNAL_H
#define ADC_INTERNAL_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/** Result of sampling all internal ADC channels. */
typedef struct
{
  int32_t vref_mv;      /*!< measured analog reference Vref+ (Vdda), mV */
  int32_t vrefint_mv;   /*!< VREFINT internal reference voltage, mV     */
  int32_t temp_mdegc;   /*!< die temperature, milli-degree Celsius      */
} adc_internal_sample_t;

/**
  * @brief  Prepare ADC1 for internal channel sampling.
  * @note   ADC1 itself is already initialized by mx_system_init(); this
  *         activates it and runs the self-calibration.
  * @retval 0 on success, negative error code on failure.
  */
int adc_internal_init(void);

/**
  * @brief  Sample all internal ADC channels (blocking, single shot).
  * @param  s  out: filled sample
  * @retval 0 on success, negative error code on failure.
  */
int adc_internal_sample(adc_internal_sample_t *s);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* ADC_INTERNAL_H */