# coremark_144m

EEMBC **CoreMark 1.0** benchmark for the **STM32C542RCT6** (NUCLEO-C542RC) @ **144 MHz**.

This is an independent project that reuses the generated/peripheral infrastructure of the
sibling `board_t1/board_t1_cmake/` baseline via a relative path
(`BOARD_ROOT = ../board_t1_cmake`) — the CMSIS packs, STM32C5 DFP, HAL/LL drivers and
board init are **not** copied here. Its own `user_modifiable/Device/STM32C542RCT6/` holds
this project's linker script, startup and system files, so its stack/heap layout can be
tuned independently of the board baseline.

## Build

From `coremark_144m/`:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File ..\board_t1_cmake\bootstrap.ps1
cmake --preset release_GCC_NUCLEO-C542RC        :: or release_ARMCLANG_...
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