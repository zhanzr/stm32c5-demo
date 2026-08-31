# dhry_144m

**Dhrystone 2.1** benchmark for the **STM32C542RCT6** (NUCLEO-C542RC) @ **144 MHz**.

This is an independent project that reuses the generated/peripheral infrastructure of the
sibling `board_t1/board_t1_cmake/` baseline via a relative path
(`BOARD_ROOT = ../board_t1_cmake`) — the CMSIS packs, STM32C5 DFP, HAL/LL drivers and
board init are **not** copied here.

> Dhrystone is intentionally compiled **without LTO** (`-flto` is never applied).
> Aggressive per-function optimisation is used instead (`-Ofast -ffast-math
> -funroll-loops` for GCC, `-O3 -ffast-math -funroll-loops` for ST LLVM).

## Source layout

```
dhry_144m/
├── CMakeLists.txt         # board_t1_cmake via ../board_t1_cmake; aggressive flags, no LTO
├── CMakePresets.json      # debug_GCC / release_GCC / release_ARMCLANG (Ninja)
└── src/
    ├── main.c             # entry: init, run dhry_main() in a loop, print DMIPS/MHz
    ├── dhry_1.c       dhry_2.c       dhry.h   # Dhrystone 2.1
    ├── custom_def.h                        # RUN_NUMBER, tick rate, compiler name
    ├── utils.c / utils.h                   # tick helper / PRINTF macro
    └── crt0_clang.c       # CLANG-only: _mainCRTStartup/_start (.data copy) + _sbrk
```

## Build

From `dhry_144m/`:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File ..\board_t1_cmake\bootstrap.ps1
cmake --preset release_GCC_NUCLEO-C542RC        :: or debug_GCC_... / release_ARMCLANG_...
cd build\release_GCC_NUCLEO-C542RC
ninja            :: dhry_144m.elf
ninja flash      :: program the MCU
ninja capture    :: see the Dhrystone results on the ST-Link VCP (COM73)
```

The preset targets the same hardware as the board baseline, so the same build-dir names
(`build\<config>`) and `ninja flash` / `ninja capture` targets are used.

## Results @ 144 MHz

| Compiler | DMIPS/MHz | Dhrystones/s | Time/run |
|----------|-----------|--------------|----------|
| Arm GCC | **1.459** | 369,071 | 2.710 µs |
| ST LLVM (`starm-clang`) | **1.559** | 394,400 | 2.535 µs |

Run count is `RUN_NUMBER = 2000000` (see `src/custom_def.h`).

## Note on the CLANG crt0/`_sbrk` shim

The ST LLVM (ARMCLANG) build needs a small CLANG-only runtime shim (`src/crt0_clang.c`):
the ST newlib crt0 does not copy `.data` (see the board-level AGENTS/`board_t1_cmake`
README), and its `_sbrk` lets the heap grow into the stack. This file fixes both. It is
compiled only for the `CLANG` compiler family (see `CMakeLists.txt`).