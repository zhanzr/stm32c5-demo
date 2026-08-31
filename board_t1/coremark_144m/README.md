# coremark_144m

EEMBC **CoreMark 1.0** benchmark for the **STM32C542RCT6** (NUCLEO-C542RC) @ **144 MHz**.

This is an independent project that reuses the generated/peripheral infrastructure of the
sibling `board_t1/board_t1_cmake/` baseline via a relative path
(`BOARD_ROOT = ../board_t1_cmake`) — the CMSIS packs, STM32C5 DFP, HAL/LL drivers and
board init are **not** copied here.

## Source layout

```
coremark_144m/
├── CMakeLists.txt         # board_t1_cmake via ../board_t1_cmake; + aggressive flags
├── CMakePresets.json      # debug_GCC / release_GCC / release_ARMCLANG (Ninja)
├── coremark_1_0_1/        # upstream EEMBC CoreMark 1.0 sources
└── src/
    ├── main.c             # entry: init, run coremark_main in a loop, print results
    ├── core_portme.c      # port: ticks via HAL_GetTick(), malloc, portable_*()
    ├── core_portme.h      # CoreMark port config/types, ee_printf -> printf
    └── crt0_clang.c       # CLANG-only: _mainCRTStartup/_start (.data copy) + _sbrk
```

## Build

From `coremark_144m/`:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File ..\board_t1_cmake\bootstrap.ps1
cmake --preset release_GCC_NUCLEO-C542RC        :: or debug_GCC_... / release_ARMCLANG_...
cd build\release_GCC_NUCLEO-C542RC
ninja            :: coremark_144m.elf
ninja flash      :: program the MCU
ninja capture    :: see the CoreMark results on the ST-Link VCP (COM73)
```

The preset targets the same hardware as the board baseline, so the same build-dir names
(`build\<config>`) and `ninja flash` / `ninja capture` targets are used.

## Results @ 144 MHz

| Compiler | Flags | CoreMark 1.0 |
|----------|-------|--------------|
| Arm GCC | `-Ofast -ffast-math -funroll-loops` | **435.3** |
| ST LLVM (`starm-clang`) | `-O3 -ffast-math -funroll-loops` | **428.4** |

All runs validate with `Correct operation validated.`

## Note on the CLANG crt0/`_sbrk` shim

The ST LLVM (ARMCLANG) build needs a small CLANG-only runtime shim (`src/crt0_clang.c`):
the ST newlib crt0 does not copy `.data` (see the board-level AGENTS/`board_t1_cmake`
README), and its `_sbrk` lets the heap grow into the stack. This file fixes both. It is
compiled only for the `CLANG` compiler family (see `CMakeLists.txt`).