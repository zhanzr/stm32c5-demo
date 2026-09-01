# file-format: 1.0.0
target_sources(${CMAKE_PROJECT_NAME} PRIVATE main.c main.h retarget.c)

# The ARMCLANG (ST LLVM) config uses the bundled newlib runtime and needs a
# few shims it does not ship (see armclang_runtime.c).  GCC provides these
# through its own newlib/crt0, so this file is CLANG-family only.
if(COMPILER_FAMILY STREQUAL "CLANG")
  target_sources(${CMAKE_PROJECT_NAME} PRIVATE armclang_runtime.c crt0_clang.c)
endif()
