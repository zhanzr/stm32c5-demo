# bootstrap.ps1
#
# Sets up the build environment so the CMake/Ninja build is reproducible and
# does not depend on shell-specific state. Call it before running cmake/ninja:
#
#   pwsh -File bootstrap.ps1          # or .\bootstrap.ps1
#
# Dot-source to persist for the current terminal:
#
#   . .\bootstrap.ps1
#
# The script resolves every tool to an absolute path and prepends to PATH
# for the current process only. This ensures a consistent, documented tool
# set regardless of what the user has installed elsewhere.
#
# ── Required tools ─────────────────────────────────────────────────────
#   cmake >= 3.21        C:\msys64\mingw64\bin\cmake.exe  (fixed path)
#   bash                 C:\msys64\usr\bin\bash.exe        (pinmux codegen)
#   ninja                STM32CubeIDE-bundled or on PATH
#   arm-none-eabi-gcc    D:\arm-none-eabi-tc\bin           (GCC configs)
#   starm-clang          STM32CubeIDE LLVM plugin           (ARMCLANG configs)
#   STM32_Programmer_CLI D:\Program Files\...\bin           (flash)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# ── Accumulate directories to prepend to PATH ──────────────────────────
$found = @()
function Add-Path([string]$Dir) {
  if ($Dir -and (Test-Path $Dir)) { $script:found += $Dir }
}

function Test-Exe([string]$Dir, [string]$Name) {
  $p = Join-Path $Dir $Name; if (Test-Path $p) { return $p } else { return $null }
}

# ───────────────────────────────────────────────────────────────────────
# 1. CMake  (fixed: MSYS2 mingw64)
# ───────────────────────────────────────────────────────────────────────
$msys2Cmake = 'C:\msys64\mingw64\bin\cmake.exe'
$cmake = Test-Exe 'C:\msys64\mingw64\bin' 'cmake.exe'
if (-not $cmake) { Write-Warning "MSYS2 cmake not found at $msys2Cmake. Install MSYS2 or set path."; break }
$v = & $cmake --version 2>&1 | Select-Object -First 1
if ($v -match '(\d+)\.(\d+)') {
  if ([int]$Matches[1] -lt 3 -or ([int]$Matches[1] -eq 3 -and [int]$Matches[2] -lt 21)) {
    Write-Warning "cmake $($Matches[1]).$($Matches[2]) < 3.21 cannot read CMakePresets.json v3."
  }
}
Write-Host "cmake: $cmake"
Add-Path 'C:\msys64\mingw64\bin'

# ───────────────────────────────────────────────────────────────────────
# 2. Bash  (fixed: MSYS2 — for pinmux / codegen scripts)
# ───────────────────────────────────────────────────────────────────────
$bash = Test-Exe 'C:\msys64\usr\bin' 'bash.exe'
if (-not $bash) { Write-Warning "MSYS2 bash not found at C:\msys64\usr\bin\bash.exe." }
else { Write-Host "bash:  $bash" }

# ───────────────────────────────────────────────────────────────────────
# 3. Ninja  (prefer STM32CubeIDE-bundled for reproducibility, else PATH)
# ───────────────────────────────────────────────────────────────────────
$ninja = $null
# Search STM32CubeIDE plugins (newest bundled ninja first) so builds use a fixed,
# documented ninja rather than whatever happens to be on PATH.
foreach ($root_ in @('D:\ST', "$env:LOCALAPPDATA\ST")) {
  if (-not (Test-Path $root_)) { continue }
  $ideDirs = Get-ChildItem $root_ -Directory -Filter 'STM32CubeIDE_*' -ErrorAction SilentlyContinue
  foreach ($ide in $ideDirs) {
    $plugins = Join-Path $ide.FullName 'STM32CubeIDE\plugins'
    if (-not (Test-Path $plugins)) { continue }
    $hits = Get-ChildItem $plugins -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -like '*externaltools.ninja.win32_*' } |
      Sort-Object { if ($_.Name -match '_(\d+)\.(\d+)\.(\d+)\.(\d+)') {
        [string]::Format('{0:D4}.{1:D4}.{2:D4}.{3:D10}',
          [int]$Matches[1],[int]$Matches[2],[int]$Matches[3],[long]$Matches[4])
      } else { '0000.0000.0000.0000000000' } } -Descending
    foreach ($h in $hits) {
      $p = Test-Exe (Join-Path $h.FullName 'tools\bin') 'ninja.exe'
      if ($p) { $ninja = $p; break }
    }
  }
  if ($ninja) { break }
}
if (-not $ninja) {
  $ninja = Get-Command ninja -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
}
if ($ninja) { Write-Host "ninja: $ninja"; Add-Path (Split-Path $ninja) }
else { Write-Warning "ninja not found. Add its bin/ directory to PATH." }

# ───────────────────────────────────────────────────────────────────────
# 4. GCC  (arm-none-eabi)
# ───────────────────────────────────────────────────────────────────────
$gcc = Get-Command arm-none-eabi-gcc -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $gcc) {
  foreach ($c in @('D:\arm-none-eabi-tc\bin', "$env:USERPROFILE\arm-none-eabi-tc\bin")) {
    $p = Test-Exe $c 'arm-none-eabi-gcc.exe'
    if ($p) { $gcc = $p; break }
  }
}
if ($gcc) { Write-Host "gcc:   $gcc"; Add-Path (Split-Path $gcc) }
else { Write-Warning "arm-none-eabi-gcc not found. GCC presets require it on PATH." }

# ───────────────────────────────────────────────────────────────────────
# 5. ARMCLANG — ST LLVM (default and only supported dist)
# ───────────────────────────────────────────────────────────────────────
# The ARMCLANG config uses ST's LLVM/Clang toolchain (starm-clang + LLD) bundled
# with STM32CubeIDE. Only the ST dist is wired (see cmake/STLLVM.cmake).
$stllvm = Get-Command starm-clang -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $stllvm) {
  # Search STM32CubeIDE plugins for the LLVM toolchain
  foreach ($root_ in @('D:\ST', "$env:LOCALAPPDATA\ST")) {
    if (-not (Test-Path $root_)) { continue }
    $ideDirs = Get-ChildItem $root_ -Directory -Filter 'STM32CubeIDE_*' -ErrorAction SilentlyContinue
    foreach ($ide in $ideDirs) {
      $plugins = Join-Path $ide.FullName 'STM32CubeIDE\plugins'
      if (-not (Test-Path $plugins)) { continue }
      $hits = Get-ChildItem $plugins -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '*externaltools.llvm.win32_*' }
      foreach ($h in $hits) {
        $p = Test-Exe (Join-Path $h.FullName 'tools\bin') 'starm-clang.exe'
        if ($p) { $stllvm = $p; break }
      }
    }
    if ($stllvm) { break }
  }
}
if ($stllvm) {
  Write-Host "starm-clang (ST LLVM): $stllvm"
  Add-Path (Split-Path $stllvm)
} else {
  Write-Warning "starm-clang not found. ARMCLANG presets require it on PATH."
}

# ───────────────────────────────────────────────────────────────────────
# 6. STM32CubeProgrammer  (for ninja flash)
# ───────────────────────────────────────────────────────────────────────
$prog = Get-Command STM32_Programmer_CLI -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $prog) {
  foreach ($d in @(
    'D:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin',
    "$env:ProgramFiles\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin"
  )) {
    $p = Test-Exe $d 'STM32_Programmer_CLI.exe'
    if ($p) { $prog = $p; break }
  }
}
if ($prog) { Write-Host "flash: $prog"; Add-Path (Split-Path $prog) }
else { Write-Warning "STM32_Programmer_CLI not found. Set -DSTM32_PROGRAMMER=<path>." }

# ───────────────────────────────────────────────────────────────────────
# Apply PATH
# ───────────────────────────────────────────────────────────────────────
$dirs = $found | Select-Object -Unique
if ($dirs.Count -gt 0) {
  $env:PATH = ($dirs -join ';') + ';' + $env:PATH
  Write-Host "`nPrepended to PATH:`n  $($dirs -join "`n  ")"
}

Write-Host "`nEnvironment ready. Example (from ${root}):"
Write-Host "  cmake --preset debug_GCC_NUCLEO-C542RC"
Write-Host "  cd build\debug_GCC_NUCLEO-C542RC; ninja hex; ninja flash"
Write-Host "  # ARMCLANG (ST LLVM): cmake --preset release_ARMCLANG_NUCLEO-C542RC"
