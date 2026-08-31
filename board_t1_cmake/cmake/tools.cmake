# file-format: 1.0.0
# Custom Ninja targets for this project, generated per build configuration.
# CONFIG_ELF / CONFIG_HEX / _OUT_DIR come from cmake/config.cmake.
#
# Usage (run from the build dir of a configuration, e.g.
#   build/debug_GCC_NUCLEO-C542RC):
#   ninja                  -> build the ELF
#   ninja hex              -> build the .hex image
#   ninja flash            -> flash the device via STM32CubeProgrammer
#   ninja capture          -> capture UART output from the ST-Link VCP port
#
# The Programmer path is resolved via the STM32_PROGRAMMER cache variable
# (set from the STM32CubeProgrammer install or overridden by the user). This
# keeps the build reproducible across machines.

# ---- Reproducible tool paths ---------------------------------------------
if(NOT DEFINED STM32_PROGRAMMER)
  find_program(STM32_PROGRAMMER
    NAMES STM32_Programmer_CLI
    PATHS "D:/Program Files/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin"
          "C:/Program Files/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin"
          "C:/Program Files (x86)/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin"
    NO_DEFAULT_PATH)
endif()
if(NOT STM32_PROGRAMMER)
  message(STATUS "STM32_Programmer_CLI.exe not found; 'ninja flash' will be unavailable. "
                 "Set -DSTM32_PROGRAMMER=<path> to enable it.")
endif()

# ---- ninja hex : generate Intel HEX from the ELF ---------------------------
add_custom_target(hex
  COMMAND ${CMAKE_OBJCOPY} -O ihex ${CONFIG_ELF} ${CONFIG_HEX}
  COMMAND ${CMAKE_SIZE}   ${CONFIG_ELF}
  DEPENDS ${CMAKE_PROJECT_NAME}
  COMMENT "Generating ${CONFIG_HEX}"
  VERBATIM
)

# ---- ninja flash : program the MCU with STM32CubeProgrammer ----------------
if(STM32_PROGRAMMER)
  add_custom_target(flash
    COMMAND "${STM32_PROGRAMMER}" -c port=SWD mode=UR
            -w ${CONFIG_ELF} -v
            -rst
    DEPENDS ${CMAKE_PROJECT_NAME}
    COMMENT "Flashing ${CONFIG_ELF} via STM32CubeProgrammer"
    VERBATIM
  )
else()
  add_custom_target(flash
    COMMAND ${CMAKE_COMMAND} -E echo "flash unavailable: set -DSTM32_PROGRAMMER=<path>"
    VERBATIM
  )
endif()

# ---- ninja capture : capture/verify UART output on the ST-Link VCP ----------
if(NOT DEFINED CAPTURE_SCRIPT)
  set(CAPTURE_SCRIPT "${CMAKE_SOURCE_DIR}/capture.ps1")
endif()
find_program(CMAKE_POWERSHELL_EXECUTABLE NAMES powershell powershell.exe)
if(NOT CMAKE_POWERSHELL_EXECUTABLE)
  message(FATAL_ERROR "PowerShell not found; cannot run 'ninja capture'")
endif()
add_custom_target(capture
  COMMAND "${CMAKE_POWERSHELL_EXECUTABLE}" -NoProfile -ExecutionPolicy Bypass -File "${CAPTURE_SCRIPT}"
  COMMENT "Capturing UART output (ST-Link VCP, 115200 baud)"
  VERBATIM
)
