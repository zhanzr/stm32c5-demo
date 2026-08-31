# file-format: 1.0.0
# Toolchain file for the ST Microelectronics LLVM/Clang toolchain (starm-clang).
# Used when COMPILER_ID == "ARMCLANG" (CMSIS_Tcompiler == "GCC").
#
# This is an ELF/GNU-style toolchain: the compiler is starm-clang (clang-based),
# the linker is LLD (starm-lld), and the GNU linker script (.ld) from the DFP
# is shared with the GCC path.

set(CMAKE_SYSTEM_NAME               Generic)
set(CMAKE_SYSTEM_PROCESSOR          arm)

# ---- CPU / FPU / DSP flags (same semantics as GCC.14.3.1.cmake) ---------
# These become compile+link flags via ${CPU_FLAGS} in cmake/flags.cmake.
if(CPU STREQUAL "Cortex-M0")
  set(CPU_FLAGS -mcpu=cortex-m0)
elseif(CPU STREQUAL "Cortex-M0+")
  set(CPU_FLAGS -mcpu=cortex-m0plus)
elseif(CPU STREQUAL "Cortex-M1")
  set(CPU_FLAGS -mcpu=cortex-m1)
elseif(CPU STREQUAL "Cortex-M3")
  set(CPU_FLAGS -mcpu=cortex-m3)
elseif(CPU STREQUAL "Cortex-M4")
  if(FPU STREQUAL "SP_FPU")
    set(CPU_FLAGS -mcpu=cortex-m4 -mfpu=fpv4-sp-d16 -mfloat-abi=hard)
  else()
    set(CPU_FLAGS -mcpu=cortex-m4)
  endif()
elseif(CPU STREQUAL "Cortex-M7")
  if(FPU STREQUAL "DP_FPU")
    set(CPU_FLAGS -mcpu=cortex-m7 -mfpu=fpv5-d16 -mfloat-abi=hard)
  elseif(FPU STREQUAL "SP_FPU")
    set(CPU_FLAGS -mcpu=cortex-m7 -mfpu=fpv5-sp-d16 -mfloat-abi=hard)
  else()
    set(CPU_FLAGS -mcpu=cortex-m7)
  endif()
elseif(CPU STREQUAL "Cortex-M23")
  set(CPU_FLAGS -mcpu=cortex-m23)
elseif(CPU STREQUAL "Cortex-M33")
  if(FPU STREQUAL "SP_FPU")
    if(DSP STREQUAL "DSP")
      set(CPU_FLAGS -mcpu=cortex-m33 -mfpu=fpv5-sp-d16 -mfloat-abi=hard)
    else()
      set(CPU_FLAGS -mcpu=cortex-m33+nodsp -mfpu=fpv5-sp-d16 -mfloat-abi=hard)
    endif()
  else()
    if(DSP STREQUAL "DSP")
      set(CPU_FLAGS -mcpu=cortex-m33)
    else()
      set(CPU_FLAGS -mcpu=cortex-m33+nodsp)
    endif()
  endif()
elseif(CPU STREQUAL "Cortex-M35P")
  if(FPU STREQUAL "SP_FPU")
    if(DSP STREQUAL "DSP")
      set(CPU_FLAGS -mcpu=cortex-m35p -mfpu=fpv5-sp-d16 -mfloat-abi=hard)
    else()
      set(CPU_FLAGS -mcpu=cortex-m35p+nodsp -mfpu=fpv5-sp-d16 -mfloat-abi=hard)
    endif()
  else()
    if(DSP STREQUAL "DSP")
      set(CPU_FLAGS -mcpu=cortex-m35p)
    else()
      set(CPU_FLAGS -mcpu=cortex-m35p+nodsp)
    endif()
  endif()
elseif(CPU STREQUAL "Cortex-M55")
  if(FPU STREQUAL "NO_FPU")
    set(CPU_FLAGS -mcpu=cortex-m55+nofp)
  else()
    set(CPU_FLAGS -mcpu=cortex-m55 -mfloat-abi=hard)
  endif()
else()
  set(CPU_FLAGS "-mcpu=${CPU}")
endif()

if(BYTE_ORDER STREQUAL "Little-endian")
  set(CPU_FLAGS ${CPU_FLAGS} -mlittle-endian)
elseif(BYTE_ORDER STREQUAL "Big-endian")
  set(CPU_FLAGS ${CPU_FLAGS} -mbig-endian)
endif()

set(CPU_FLAGS ${CPU_FLAGS} -mthumb)

if(SECURE STREQUAL "Secure" OR SECURE STREQUAL "Secure-only")
  set(CC_SECURE -mcmse)
endif()

# ---- Find the ST LLVM compiler ------------------------------------------------
find_program(STLLVM_C_COMPILER NAMES starm-clang starm-clang.exe)
if(NOT STLLVM_C_COMPILER)
  message(FATAL_ERROR
    "starm-clang not found.  Add the ST LLVM tools bin/ directory to PATH:\n"
    "  D:\\ST\\STM32CubeIDE_*\\...\\externaltools.llvm.win32_1.0.200.\\tools\\bin")
endif()
get_filename_component(STLLVM_BIN_DIR "${STLLVM_C_COMPILER}" DIRECTORY)

set(CMAKE_C_COMPILER   "${STLLVM_C_COMPILER}")
set(CMAKE_CXX_COMPILER "${STLLVM_C_COMPILER}")

# Use the ELF linker (lld) via the clang driver.
find_program(STLLVM_LINKER NAMES starm-lld starm-lld.exe ld.lld ld.lld.exe
  HINTS "${STLLVM_BIN_DIR}")
if(NOT STLLVM_LINKER)
  message(FATAL_ERROR "starm-lld / ld.lld not found in ${STLLVM_BIN_DIR}")
endif()

set(CMAKE_C_COMPILER_ID   "Clang")
set(CMAKE_CXX_COMPILER_ID "Clang")

# ---- Objcopy / size -----------------------------------------------------------
find_program(CMAKE_OBJCOPY NAMES starm-objcopy arm-none-eabi-objcopy
  HINTS "${STLLVM_BIN_DIR}")
find_program(CMAKE_SIZE    NAMES starm-size    arm-none-eabi-size
  HINTS "${STLLVM_BIN_DIR}")

# ---- Newlib runtime (instead of the default picolibc) -------------------------
# ST clang defaults to the picolibc runtime under
#   lib/clang-runtimes/<arm-none-eabi>/<triplet>/lib
# but the generated startup + syscalls/sysmem here are newlib-flavoured.  Select
# the matching newlib runtime triplet explicitly (Cortex-M33 + hard-float).
get_filename_component(STLLVM_ROOT "${STLLVM_BIN_DIR}/.." ABSOLUTE)
set(STLLVM_NEWLIB_ROOT "${STLLVM_ROOT}/lib/clang-runtimes/newlib/arm-none-eabi")
set(STLLVM_NEWLIB_TRIPLET "armv8m.main_hard_fp_exn_rtti_unaligned_size")
set(STLLVM_NEWLIB_LIB "${STLLVM_NEWLIB_ROOT}/${STLLVM_NEWLIB_TRIPLET}/lib")
set(STLLVM_NEWLIB_INC "${STLLVM_NEWLIB_ROOT}/include")
if(NOT EXISTS "${STLLVM_NEWLIB_LIB}/libc.a")
  message(WARNING "ST newlib runtime lib not found at ${STLLVM_NEWLIB_LIB}; "
                  "link will fall back to ST clang defaults.")
endif()
# Point the C/C++ standard library search path at newlib (instead of the
# picolibc that ST clang otherwise injects).  -nostdlib stops the driver
# injecting its default (picolibc) runtime; crt0-nosys provides _start, libc
# /libm the C library, libnosys the syscall stubs and builtins the compiler
# runtime.  The DFP syscalls.c/sysmem.c are excluded for CLANG (components.cmake)
# and the small extra symbols (__stack_limit, __aeabi_read_tp) come from the
# project's armclang_runtime.c.  Link the runtimes by absolute path (no -L/-l,
# which the ST clang driver mishandles when tokenised); --start-group resolves
# the circular references between these archives.
set(_NL "${STLLVM_NEWLIB_LIB}")
set(CMAKE_C_STANDARD_LIBRARIES
  "-nostdlib -Wl,--start-group ${_NL}/libcrt0-nosys.a ${_NL}/libc.a ${_NL}/libm.a ${_NL}/libnosys.a ${_NL}/libclang_rt.builtins.a -Wl,--end-group")
set(CMAKE_CXX_STANDARD_LIBRARIES "${CMAKE_C_STANDARD_LIBRARIES}")
unset(_NL)

# Skip try-compile (bare-metal, no full libc/OS to detect).
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# ---- Target triple and initial flags ------------------------------------------
# --target=arm-st-none-eabi is the ST LLVM bare-metal triple.
# CPU_FLAGS (from target.cmake) are applied in cmake/flags.cmake via
# target_compile_options() so they are not baked into CMAKE_C_FLAGS_INIT.
set(CMAKE_C_FLAGS_INIT   "--target=arm-st-none-eabi -isystem ${STLLVM_NEWLIB_INC}")
set(CMAKE_CXX_FLAGS_INIT "--target=arm-st-none-eabi -isystem ${STLLVM_NEWLIB_INC}")
set(CMAKE_ASM_FLAGS_INIT "--target=arm-st-none-eabi")
