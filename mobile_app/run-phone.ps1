<#
.SYNOPSIS
  Runs the app on an Android phone over Wi-Fi (Wireless debugging), pointed
  at the backend running on this laptop.

.DESCRIPTION
  Finds adb, discovers the phone's Wireless debugging port, connects, works
  out this laptop's IP on the phone's network, checks the backend is
  reachable, then runs `flutter run` with --dart-define=API_HOST=<laptop IP>.

  Phone: Settings > Developer options > Wireless debugging (ON), on the same
  Wi-Fi as this laptop. The backend must be running (cd backend; npm run dev).

.EXAMPLE
  .\run-phone.ps1
  Connect to the phone and run the app.

.EXAMPLE
  .\run-phone.ps1 -Pair
  First time (or after the phone forgot this laptop): open "Pair device with
  pairing code" on the phone, run this, and type the 6-digit code.

.EXAMPLE
  .\run-phone.ps1 -DryRun
  Show what would run without building anything.

.EXAMPLE
  .\run-phone.ps1 --release
  Anything the script doesn't recognise is passed on to `flutter run`.
#>
# Named-only parameters, so loose arguments like --release go to flutter.
[CmdletBinding(PositionalBinding = $false)]
param(
  # Pair with the phone first (needs the pairing-code dialog open on it).
  [switch]$Pair,
  # Phone address as ip:port, if auto-discovery doesn't find it.
  [string]$Device,
  # Laptop IP the phone should use for the backend, if auto-detection is wrong.
  [string]$ApiHost,
  [int]$ApiPort = 5000,
  # Print the resolved command instead of running it.
  [switch]$DryRun,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Write-Step($message) { Write-Host "==> $message" -ForegroundColor Cyan }
function Write-Warn($message) { Write-Host "  ! $message" -ForegroundColor Yellow }
function Stop-WithError($message) {
  Write-Host "  x $message" -ForegroundColor Red
  exit 1
}

# --- adb ------------------------------------------------------------------
function Find-Adb {
  $onPath = Get-Command adb -ErrorAction SilentlyContinue
  if ($onPath) { return $onPath.Source }
  $sdkRoots = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, "$env:LOCALAPPDATA\Android\Sdk") |
    Where-Object { $_ }
  foreach ($root in $sdkRoots) {
    $candidate = Join-Path $root "platform-tools\adb.exe"
    if (Test-Path $candidate) { return $candidate }
  }
  return $null
}

$adb = Find-Adb
if (-not $adb) { Stop-WithError "adb not found. Install Android SDK Platform-Tools (Android Studio > SDK Manager)." }

# Wireless debugging services the phone advertises, e.g. 192.168.1.22:43397.
function Get-MdnsEndpoints([string]$serviceType) {
  $lines = & $adb mdns services 2>$null
  $endpoints = @()
  foreach ($line in $lines) {
    if ($line -match [regex]::Escape($serviceType) -and $line -match '(\d{1,3}(\.\d{1,3}){3}:\d+)') {
      $endpoints += $Matches[1]
    }
  }
  return ,$endpoints
}

# Phones adb already talks to over the network (ip:port entries).
function Get-ConnectedWifiDevices {
  $devices = @()
  foreach ($line in (& $adb devices)) {
    if ($line -match '^(\d{1,3}(\.\d{1,3}){3}:\d+)\s+device\b') { $devices += $Matches[1] }
  }
  return ,$devices
}

& $adb start-server 2>$null | Out-Null

# --- pairing (optional) ---------------------------------------------------
if ($Pair) {
  Write-Step "Pairing"
  Write-Host "    On the phone: Wireless debugging > Pair device with pairing code (keep it open)."
  $pairing = Get-MdnsEndpoints "_adb-tls-pairing._tcp"
  if ($pairing.Count -gt 0) {
    $pairEndpoint = $pairing[0]
    Write-Host "    Found the pairing dialog at $pairEndpoint"
  } else {
    $pairEndpoint = Read-Host "    Couldn't find it automatically. Type the IP address & Port shown in the dialog"
  }
  $code = Read-Host "    Wi-Fi pairing code"
  $pairOutput = & $adb pair $pairEndpoint $code 2>&1
  Write-Host "    $pairOutput"
  if ("$pairOutput" -notmatch "Successfully paired") {
    Stop-WithError "Pairing failed. Codes are single-use: reopen the pairing dialog and try again."
  }
  Start-Sleep -Seconds 2
}

# --- connect --------------------------------------------------------------
Write-Step "Finding the phone"
if (-not $Device) {
  $connectable = Get-MdnsEndpoints "_adb-tls-connect._tcp"
  if ($connectable.Count -gt 0) {
    $Device = $connectable[0]
  } else {
    $already = Get-ConnectedWifiDevices
    if ($already.Count -gt 0) { $Device = $already[0] }
  }
}
if (-not $Device) {
  Write-Warn "No phone found. Check that Wireless debugging is ON and the phone is on the same Wi-Fi."
  Write-Warn "First time on this laptop? Run:  .\run-phone.ps1 -Pair"
  Write-Warn "Or pass the address from the Wireless debugging screen:  .\run-phone.ps1 -Device 192.168.1.22:43397"
  exit 1
}

if ((Get-ConnectedWifiDevices) -notcontains $Device) {
  $connectOutput = & $adb connect $Device 2>&1
  if ("$connectOutput" -notmatch "connected to") {
    Write-Warn "$connectOutput"
    Stop-WithError "Couldn't connect to $Device. If the phone was never paired with this laptop, run .\run-phone.ps1 -Pair"
  }
}
$model = (& $adb -s $Device shell getprop ro.product.model 2>$null | Out-String).Trim()
Write-Host "    Connected: $Device ($model)"

# --- laptop IP ------------------------------------------------------------
# The IPv4 address of the interface on the same network as the phone.
function Test-SameSubnet([string]$a, [string]$b, [int]$prefix) {
  $toInt = { param($ip) $bytes = ([System.Net.IPAddress]::Parse($ip)).GetAddressBytes(); [Array]::Reverse($bytes); [BitConverter]::ToUInt32($bytes, 0) }
  $mask = if ($prefix -eq 0) { [uint32]0 } else { [uint32]([math]::Pow(2, 32) - [math]::Pow(2, 32 - $prefix)) }
  return ((& $toInt $a) -band $mask) -eq ((& $toInt $b) -band $mask)
}

if (-not $ApiHost) {
  Write-Step "Finding this laptop's IP"
  $phoneIp = $Device.Split(":")[0]
  $candidates = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" }
  $match = $candidates | Where-Object { Test-SameSubnet $_.IPAddress $phoneIp $_.PrefixLength } | Select-Object -First 1
  if (-not $match) {
    Stop-WithError "This laptop isn't on the same network as the phone ($phoneIp). Connect both to the same Wi-Fi, or pass -ApiHost <laptop IP>."
  }
  $ApiHost = $match.IPAddress
}
Write-Host "    Backend address for the phone: http://${ApiHost}:$ApiPort"

# --- backend --------------------------------------------------------------
Write-Step "Checking the backend"
$healthUrl = "http://${ApiHost}:$ApiPort/api/health"
try {
  Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 4 | Out-Null
  $fromPhone = (& $adb -s $Device shell "curl -s -m 5 $healthUrl" 2>$null | Out-String)
  if ($fromPhone -match '"success"\s*:\s*true') {
    Write-Host "    Backend is running and the phone can reach it."
  } else {
    Write-Warn "The backend runs, but the phone can't reach it. Allow Node.js through Windows Firewall (Private and Public networks)."
  }
} catch {
  Write-Warn "Backend isn't answering at $healthUrl. Start it in another window:  cd backend; npm run dev"
}

# --- run ------------------------------------------------------------------
# Gradle's Kotlin compile daemon hangs on this laptop when RAM is tight;
# compiling inside the Gradle process avoids it.
[Environment]::SetEnvironmentVariable("ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy", "in-process", "Process")

$runArgs = @("run", "-d", $Device, "--dart-define=API_HOST=$ApiHost", "--dart-define=API_PORT=$ApiPort") + $FlutterArgs
Write-Step "flutter $($runArgs -join ' ')"
if ($DryRun) { exit 0 }
Write-Host "    Tap Install on the phone if it asks. Don't swipe the app away from Recents (it cuts the debugger) - press Home instead."
& flutter @runArgs
exit $LASTEXITCODE
