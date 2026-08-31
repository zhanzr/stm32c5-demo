cmake_minimum_required(VERSION 3.30)

set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)
set(CMAKE_C_COMPILER_FORCED TRUE)
set(CMAKE_CXX_COMPILER_FORCED TRUE)

# Resolve shared infrastructure from board_t1_cmake one level up.
set(BOARD_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")

include(${BOARD_ROOT}/cmake/target.cmake)
include(${BOARD_ROOT}/cmake/${TOOLCHAIN_FILE})

project(dhry_144m C ASM)
add_executable(dhry_144m)

include(${BOARD_ROOT}/cmake/config.cmake)
include(${BOARD_ROOT}/cmake/flags.cmake)
include(${BOARD_ROOT}/cmake/components.cmake)
include(${BOARD_ROOT}/cmake/tools.cmake)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

target_sources(dhry_144m PRIVATE
  src/main.c
  src/utils.c
  src/dhry_1.c
  src/dhry_2.c
  ${BOARD_ROOT}/retarget.c
)

# The ARMCLANG (ST LLVM) config needs the newlib shim from the board root,
# plus a CLANG-only crt0 that copies .data (the ST newlib crt0 leaves the
# data-copy hook NULL, so static globals would never be initialized).
if(COMPILER_FAMILY STREQUAL "CLANG")
  target_sources(dhry_144m PRIVATE
    ${BOARD_ROOT}/armclang_runtime.c
    src/crt0_clang.c
  )
endif()

target_include_directories(dhry_144m PRIVATE
  src
)

# --- Aggressive optimization flags: Dhrystone must NOT use LTO (release only) ---
if(NOT BUILD_TYPE STREQUAL "debug")
  if(COMPILER_FAMILY STREQUAL "GCC")
    target_compile_options(dhry_144m PRIVATE
      SHELL:-Ofast -ffast-math -funroll-loops
    )
    # newlib-nano printf does not support %f by default; pull in the float
    # printf variant so the Dhrystone results print (Microseconds, DMIPS/MHz).
    target_link_options(dhry_144m PRIVATE -Wl,-u,_printf_float)
  elseif(COMPILER_FAMILY STREQUAL "CLANG")
    target_compile_options(dhry_144m PRIVATE
      SHELL:-O3 -ffast-math -funroll-loops
    )
  endif()
endif()
