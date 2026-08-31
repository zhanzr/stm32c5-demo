# nucleo-c542

Repository of bare-metal **Cortex-M** firmware projects for the ST/NUCLEO boards used in
this environment. Each board lives in its own top-level folder and contains one or more
independent CMake + Ninja projects that share the board's generated device setup.

## Boards

| Board folder | MCU / board | Projects |
|--------------|-------------|----------|
| [`board_t1/`](board_t1/) | **STM32C542RCT6** (Cortex-M33, 144 MHz, NUCLEO-C542RC) | [`board_t1_cmake`](board_t1/board_t1_cmake/), [`coremark_144m`](board_t1/coremark_144m/), [`dhry_144m`](board_t1/dhry_144m/) |

Each board folder contains:

- the board's source-of-truth hardware description (`.ioc2`), board photos in
  `board_images/`, and a board-level `README.md`;
- one **baseline** project (`*_cmake/`) holding the generated/peripheral
  infrastructure (CMSIS, the STM32Cube DFP, HAL/LL drivers, board init);
- additional **independent** projects that reuse that baseline's generated files via
  relative paths (e.g. the CoreMark / Dhrystone benchmarks).

## Toolchain environment

Tool paths are pinned (rather than guessed) per machine. The reference tools are bundled
with **STM32CubeIDE 2.1.1** and Arm GCC:

| Tool | Typical path |
|------|--------------|
| CMake  | `.../com.st.stm32cube.ide.mcu.externaltools.cmake.win32_*/tools/bin/cmake.exe` |
| Ninja  | `.../com.st.stm32cube.ide.mcu.externaltools.ninja.win32_*/tools/bin/ninja.exe` |
| Arm GCC| `D:\arm-none-eabi-tc\bin\` |
| ST LLVM| `.../com.st.stm32cube.ide.mcu.externaltools.llvm.win32_*/tools/bin/` (`starm-clang`) |
| Programmer | `D:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe` |

Each project's `bootstrap.ps1` prepends these to `PATH` for a reproducible build. The
monorepo `AGENTS.md` records the exact machine paths and the guardrails to respect when
editing these projects.

## Building

Inside any project (e.g. `board_t1/board_t1_cmake/`):

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap.ps1   :: once
cmake --preset release_GCC_NUCLEO-C542RC                            :: or the preset of the project
cd build\release_GCC_NUCLEO-C542RC
ninja            :: build the ELF
ninja hex        :: Intel HEX
ninja flash      :: program the MCU (STM32CubeProgrammer, SWD)
ninja capture    :: capture UART output from the ST-Link VCP
```

See the board-level `board_t1/README.md` and the per-project `README.md` for details.

## Contributing / agent guidance

AI agents working in this repository should read [`AGENTS.md`](AGENTS.md) at the
repository root before making changes.