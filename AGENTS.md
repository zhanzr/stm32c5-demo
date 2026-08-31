# AGENTS.md

Guidance for AI coding agents working in this repository.

## Repository overview

Bare-metal **Cortex-M** firmware for ST/NUCLEO boards, built with **CMake + Ninja**
(CMSIS-Toolbox / STM32CubeMX2 generated layout). The repo is multi-board: every board
lives in its own top-level folder and contains one or more independent projects.

```
nucleo-c542/
├── AGENTS.md                 # this file (repo-wide guidance)
├── README.md                 # overall content + board index
├── .gitignore
└── board_t1/                 # one folder per board
    ├── board_t1.ioc2         # hardware config source of truth
    ├── board_images/         # board photos (embedded in board_t1/README.md)
    ├── README.md             # board-relevant README
    ├── board_t1_cmake/       # BASELINE project: generated/peripheral infra
    ├── coremark_144m/        # independent project (reuses baseline via relative path)
    └── dhry_144m/            # independent project (ditto)
```

For each board, the **baseline** `*_cmake/` project is the source of the generated /
peripheral infrastructure (CMSIS packs, DFP, HAL/LL drivers, board init, `generated/`,
`user_modifiable/`). Other projects on the same board are **independent top-level
projects** that reference that infrastructure via a relative `BOARD_ROOT` (e.g.
`coremark_144m`/`dhry_144m` set `BOARD_ROOT = ../board_t1_cmake`) rather than copying it.

## Building any project

From the project folder (e.g. `board_t1/board_t1_cmake/`, or a benchmark project that
reuses the board's `bootstrap.ps1`):

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap.ps1    :: once (pins tools on PATH)
cmake --preset release_GCC_NUCLEO-C542RC                              :: or debug_GCC_... / release_ARMCLANG_...
```

Then, from `build\<config>`:

```bat
ninja              :: build <project>.elf
ninja hex          :: build <project>.hex
ninja flash        :: program MCU via STM32CubeProgrammer (SWD, under reset)
ninja capture      :: capture UART output from the ST-Link VCP (COM auto-detected)
```

Each preset uses its own build dir: `build\debug_GCC_NUCLEO-C542RC`,
`build\release_GCC_NUCLEO-C542RC`, `build\release_ARMCLANG_NUCLEO-C542RC`.

Use CMake >= 3.21 (STM32CubeIDE-bundled); the system `cmake` 3.20.5 cannot read
`CMakePresets.json` v3.

### Concrete paths on this machine

- CMake: `D:\ST\STM32CubeIDE_2.1.1\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.cmake.win32_1.1.200.202605190741\tools\bin\cmake.exe`
- Ninja: `D:\ST\STM32CubeIDE_2.1.1\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.ninja.win32_1.1.200.202606260906\tools\bin\ninja.exe`
- GCC:  `D:\arm-none-eabi-tc\bin\arm-none-eabi-gcc.exe` (GCC 15.3.1)
- ST LLVM: `D:\ST\STM32CubeIDE_2.1.1\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.llvm.win32_1.0.200.202603311046\tools\bin\` (`starm-clang`)
- Programmer: `D:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe`
- ST-Link VCP COM port: **COM73** (1200 baud; may change — see the project `capture.ps1`)

## Conventions & cautions (apply repo-wide)

- **Generated files** (`generated/`, `user_modifiable/Device/...`) are machine-produced
  from the board `.ioc2`; prefer editing the `.ioc2` / regenerating over hand-editing, and
  be aware manual edits there may be overwritten.
- The `generated/` directory is **gitignored** and reconstructed on disk (do not rely on
  it being in git; regenerate from the `.ioc2` if missing).
- **Do not change `cmake/flags.cmake` `-Werror=implicit-function-declaration`**; declare
  functions in headers.
- Prefer compiler-agnostic `addr2line`/`nm`/CMake files that work for both GCC and
  ST LLVM; the two toolchains differ (see the ST LLVM notes below).
- The three build configs are compiler-selected via preset `COMPILER_ID` and must keep
  using separate build dirs so they never overwrite each other.

### ST LLVM / ARMCLANG (critical)

The `release_ARMCLANG` config uses ST LLVM (`starm-clang` + LLD) with the ST-bundled
**newlib** runtime. This combination has several hard-won requirements:

- **The ST newlib crt0 does NOT copy `.data`.** Its `_start`/`_mainCRTStartup` zeroes
  `.bss` but its `.data`-copy hook links to NULL. Consequently the ST LLVM build will not
  boot unless the project provides a strong `_mainCRTStartup`/`_start` that copies `.data`
  (and zeros `.bss`) explicitly — see the CLANG-only `src/crt0_clang.c` in the benchmark
  projects. The linker script must define `__data_end__` and `__etext`.
- **Newlib `_sbrk` grows the heap into the stack** under ST LLVM (it uses `__stack` as the
  heap ceiling), corrupting `malloc` (IACCVIOL). The CLANG build supplies its own `_sbrk`
  that stops at `__HeapLimit` (see `crt0_clang.c`). The linker script therefore uses a
  larger `HEAP_SIZE`/`STACK_SIZE` so `__HeapLimit` and the stack fit in RAM.
- **Stack symbols must be linker symbols, not C variables.** The CMSIS clang header maps
  `__INITIAL_SP`→`__stack` and `__STACK_LIMIT`→`__stack_limit`; `Reset_Handler` writes them
  into the M33 `MSPLIM`/`PSPLIM`/PSP registers. They must be defined in the linker script
  (`__stack = __StackTop; __stack_limit = __StackLimit;`). A C `const` `__stack_limit`
  loads a flash address into MSPLIM and crashes at reset.
- **ST clang `-L`/`-l` gotcha**: the ST clang driver mangles separate `-L <path>` tokens,
  so newlib is linked by absolute `.a` path in `cmake/STLLVM.cmake`
  (`CMAKE_C_STANDARD_LIBRARIES` is a single string; do not switch it back to `-L`/`-l`).
  Keep `STLLVM_ROOT` = `<tools>` (one level above `bin`).
- `armclang_runtime.c` supplies `__aeabi_read_tp` (newlib TLS base) and is compiled only
  for the `CLANG` family.
- The DFP "Standalone syscalls/sysmem" sources are excluded for `CLANG`
  (`cmake/components.cmake`); newlib `libnosys.a` supplies the stubs instead.

### Board / project specifics

Board- and project-specific cautions (peripheral setup, LED polarity, UART baud, expected
benchmark behaviour and results) live in each board's `board_t1/README.md` and the
per-project `README.md` files. Always check the relevant `README.md` before editing a
board or project.