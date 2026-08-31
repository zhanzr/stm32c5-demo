<#
.SYNOPSIS
  Capture UART output from the ST-Link Virtual COM Port and log it to a file.

.DESCRIPTION
  Opens the ST-Link VCP (USART2 = PA2/PA3) at 115200 baud, prints received
  bytes to the console and appends them to an optional log file.

  The COM port is auto-detected from the STMicroelectronics STLink Virtual COM
  Port. Override with the -Port parameter or the SERIAL_PORT environment
  variable. Press Ctrl+C to stop.

.PARAMETER Port
  COM port to open, e.g. COM73. If omitted the ST-Link VCP is auto-detected.

.PARAMETER BaudRate
  Baud rate, default 115200.

.PARAMETER LogFile
  Optional path to append received data to.
#>
param(
  [string]$Port,
  [int]$BaudRate = 115200,
  [string]$LogFile
)

$ErrorActionPreference = 'Stop'

if (-not $Port) {
  $Port = $env:SERIAL_PORT
}
if (-not $Port) {
  $portInfo = Get-CimInstance Win32_SerialPort -ErrorAction SilentlyContinue |
    Where-Object { $_.Description -match 'STLink|ST-Link|Virtual COM' } |
    Select-Object -First 1
  if (-not $portInfo) {
    Write-Error "No ST-Link Virtual COM port found. Pass -Port COMxx or set SERIAL_PORT."
    exit 1
  }
  $Port = $portInfo.DeviceID
}

Write-Host "Opening ${Port} @ $BaudRate baud (Ctrl+C to stop)..."
if ($LogFile) {
  Write-Host "Logging to: $LogFile"
}

$serial = New-Object System.IO.Ports.SerialPort
$serial.PortName      = $Port
$serial.BaudRate      = $BaudRate
$serial.DataBits      = 8
$serial.Parity        = [System.IO.Ports.Parity]::None
$serial.StopBits      = [System.IO.Ports.StopBits]::One
$serial.Handshake     = [System.IO.Ports.Handshake]::None
$serial.ReadTimeout   = 500
$serial.Open()

try {
  while ($true) {
    Start-Sleep -Milliseconds 50
    while ($serial.BytesToRead -gt 0) {
      $line = $serial.ReadLine()
      Write-Host $line
      if ($LogFile) {
        Add-Content -LiteralPath $LogFile -Value $line
      }
    }
  }
}
finally {
  if ($serial.IsOpen) { $serial.Close() }
  $serial.Dispose()
}
