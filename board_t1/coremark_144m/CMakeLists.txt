cmake_minimum_required(VERSION 3.30)

set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)
set(CMAKE_C_COMPILER_FORCED TRUE)
set(CMAKE_CXX_COMPILER_FORCED TRUE)

# This project reuses the generated/peripheral infrastructure of the sibling
# board_t1_cmake project (device tools, DFP, HAL/LL drivers, CMSIS, board HAL
# init, retarget, capture script) via a relative path.
set(BOARD_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../board_t1_cmake")

include(${BOARD_ROOT}/cmake/target.cmake)
include(${BOARD_ROOT}/cmake/${TOOLCHAIN_FILE})

project(coremark_144m C ASM)
add_executable(coremark_144m)

include(${BOARD_ROOT}/cmake/config.cmake)
include(${BOARD_ROOT}/cmake/flags.cmake)
include(${BOARD_ROOT}/cmake/components.cmake)
include(${BOARD_ROOT}/cmake/tools.cmake)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(CORE ${CMAKE_CURRENT_SOURCE_DIR}/coremark_1_0_1)

target_sources(coremark_144m PRIVATE
  src/main.c
  src/core_portme.c
  ${BOARD_ROOT}/retarget.c
  ${CORE}/core_list_join.c
  ${CORE}/core_main.c
  ${CORE}/core_matrix.c
  ${CORE}/core_state.c
  ${CORE}/core_util.c
)

# The ARMCLANG (ST LLVM) config needs the newlib shim from the board root,
# plus a CLANG-only crt0 that copies .data (the ST newlib crt0 leaves the
# data-copy hook NULL, so static globals would never be initialized).
if(COMPILER_FAMILY STREQUAL "CLANG")
  target_sources(coremark_144m PRIVATE
    ${BOARD_ROOT}/armclang_runtime.c
    src/crt0_clang.c
  )
endif()

target_include_directories(coremark_144m PRIVATE
  src
  ${CORE}
)

# --- Aggressive optimization flags for benchmarking (release only) ---
# GCC 15.3.1 + nano.specs + nosys fails to link when -flto is enabled
# (the linker plugin drops the syscall stubs _fstat/_isatty and hits
# unsupported-relocation during LTO recompile), so LTO is omitted here in
# favour of reliable aggressive flags.
if(NOT BUILD_TYPE STREQUAL "debug")
  if(COMPILER_FAMILY STREQUAL "GCC")
    target_compile_options(coremark_144m PRIVATE
      SHELL:-Ofast -ffast-math -funroll-loops
    )
    # newlib-nano printf does not support %f by default; pull in the float
    # printf variant so the CoreMark scores print (Dhrystone needs this too).
    target_link_options(coremark_144m PRIVATE -Wl,-u,_printf_float)
  elseif(COMPILER_FAMILY STREQUAL "CLANG")
    target_compile_options(coremark_144m PRIVATE
      SHELL:-O3 -ffast-math -funroll-loops
    )
  endif()
endif()
