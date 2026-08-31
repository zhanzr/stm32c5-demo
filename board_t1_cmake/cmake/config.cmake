# file-format: 1.0.0
# Central configuration derived from the active preset/CMAKE_BUILD_TYPE.
#
# Each preset sets BUILD_TYPE and COMPILER_ID cache variables. This module
# derives the corresponding CMSIS toolchain selector (CMSIS_Tcompiler) and the
# build/artifact directory, so every sub-cmake file stays configuration-agnostic.

if(NOT DEFINED BUILD_TYPE)
  set(BUILD_TYPE "debug")
endif()
if(NOT DEFINED COMPILER_ID)
  set(COMPILER_ID "GCC")
endif()

# Normalize to the same spellings CMSIS-Toolbox / ST packs expect.
#
# COMPILER_FAMILY controls compile/link flags in cmake/flags.cmake.
# CMSIS_Tcompiler gates DFP file selection and the DFP linker-script flag
# (the DFP passes -T<ld> only when CMSIS_Tcompiler == "GCC").
#
# For the ST LLVM toolchain (starm-clang), we need the DFP's GNU .ld and
# the same DFP-gated source files (startup, syscalls), so CMSIS_Tcompiler
# is set to "GCC" — clang accepts the GCC codegen flags just fine.
if(COMPILER_ID STREQUAL "ARMCLANG")
  set(CMSIS_Tcompiler "GCC")   # ST LLVM shares GCC file gating + .ld path
  set(COMPILER_FAMILY "CLANG")
elseif(COMPILER_ID STREQUAL "AC6")
  set(CMSIS_Tcompiler "ARMCLANG")
  set(COMPILER_FAMILY "AC6")
elseif(COMPILER_ID STREQUAL "IAR")
  set(CMSIS_Tcompiler "IAR")
  set(COMPILER_FAMILY "IAR")
else()
  set(CMSIS_Tcompiler "GCC")
  set(COMPILER_FAMILY "GCC")
endif()

# Output/artifact directory: build/<BUILD_TYPE>_<COMPILER_ID>_NUCLEO-C542RC
set(BOARD_SUFFIX "NUCLEO-C542RC")
set(BUILD_DIR_NAME "${BUILD_TYPE}_${COMPILER_ID}_${BOARD_SUFFIX}")
set(_OUT_DIR "${CMAKE_SOURCE_DIR}/build/${BUILD_DIR_NAME}")
set(CONFIG_ELF "${_OUT_DIR}/${CMAKE_PROJECT_NAME}.elf")
set(CONFIG_HEX "${_OUT_DIR}/${CMAKE_PROJECT_NAME}.hex")
set(CONFIG_MAP "${_OUT_DIR}/${CMAKE_PROJECT_NAME}.map")

message(STATUS "Config: build_type=${BUILD_TYPE} compiler=${COMPILER_ID} (${CMSIS_Tcompiler}) ${BUILD_DIR_NAME}")
