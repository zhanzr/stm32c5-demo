# file-format: 1.0.0
# Compile/link flags for the application target, per compiler and build type.
# CPU_FLAGS / CC_SECURE are provided by the selected TOOLCHAIN_FILE.
# CONFIG_* variables come from cmake/config.cmake.

set_target_properties(${CMAKE_PROJECT_NAME} PROPERTIES SUFFIX ".elf")

# ---------- Include directories (shared across compilers) -----------------
target_include_directories(${CMAKE_PROJECT_NAME} PUBLIC
  .
  arch/cmsis/CMSIS/Core/Include
  generated/hal
  stm32c5xx_dfp/Include
  stm32c5xx_drivers/hal
  stm32c5xx_drivers/ll
  stm32c5xx_drivers/timebases
  user_modifiable/_${BUILD_DIR_NAME}
)

target_compile_definitions(${CMAKE_PROJECT_NAME} PUBLIC STM32C542xx _RTE_)

target_compile_options(${CMAKE_PROJECT_NAME} PUBLIC ${CPU_FLAGS})

# ---------- Compiler-specific options -------------------------------------
if(COMPILER_FAMILY STREQUAL "GCC")
  target_compile_options(${CMAKE_PROJECT_NAME} PUBLIC
    SHELL:-fdata-sections -ffunction-sections -std=gnu11 -Wall
         -fstack-usage --specs=nano.specs --specs=nosys.specs
         -Werror=implicit-function-declaration ${CC_SECURE})
  if(BUILD_TYPE STREQUAL "debug")
    target_compile_options(${CMAKE_PROJECT_NAME} PUBLIC SHELL:-g3 -O0)
  else()
    target_compile_options(${CMAKE_PROJECT_NAME} PUBLIC SHELL:-O2)
  endif()

  target_link_options(${CMAKE_PROJECT_NAME} PUBLIC
    -Wl,-Map=${CONFIG_MAP}
    -Wl,--gc-sections
    -Wl,--start-group -lc -lm -Wl,--end-group
    -static --specs=nano.specs --specs=nosys.specs ${CC_SECURE})
  target_link_options(${CMAKE_PROJECT_NAME} PUBLIC ${CPU_FLAGS})

elseif(COMPILER_FAMILY STREQUAL "CLANG")
  # ST LLVM / Clang (starm-clang + LLD) — ELF/GNU-style, reuses the DFP .ld
  # linker script that the DFP passes via target_link_options(INTERFACE).
  target_compile_options(${CMAKE_PROJECT_NAME} PUBLIC
    SHELL:-fdata-sections -ffunction-sections -Wall
         -Werror=implicit-function-declaration
         -include stddef.h
         ${CC_SECURE})
  if(BUILD_TYPE STREQUAL "debug")
    target_compile_options(${CMAKE_PROJECT_NAME} PUBLIC SHELL:-g -O0)
  else()
    target_compile_options(${CMAKE_PROJECT_NAME} PUBLIC SHELL:-O2)
  endif()

  target_link_options(${CMAKE_PROJECT_NAME} PUBLIC
    -nostartfiles
    -Wl,-Map=${CONFIG_MAP}
    -Wl,--gc-sections
    ${CC_SECURE})
  target_link_options(${CMAKE_PROJECT_NAME} PUBLIC ${CPU_FLAGS})

elseif(COMPILER_FAMILY STREQUAL "AC6")
  # Arm Compiler 6 (armclang / armlink) — Keil MDK path (not yet fully wired).
  message(FATAL_ERROR
    "COMPILER_FAMILY=AC6 (Keil armclang/armlink) is not yet wired. "
    "Use COMPILER_ID=ARMCLANG for the ST LLVM toolchain.")
endif()

# ---------- Clean generated files -----------------------------------------
set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_CLEAN_FILES "${CONFIG_MAP}")
set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_CLEAN_FILES "${CONFIG_ELF}")
