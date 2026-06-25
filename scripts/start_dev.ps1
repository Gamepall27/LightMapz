param(
  [int]$BackendPort = 3000,
  [int]$FrontendPort = 8081
)

$ErrorActionPreference = "Stop"

$rootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$backendDir = Join-Path $rootDir "backend"
$backendHealthUrl = "http://127.0.0.1:$BackendPort/health"
$apiBaseUrl = "http://127.0.0.1:$BackendPort"
$backendJob = $null

function Find-Flutter {
  $command = Get-Command flutter -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $candidates = @(
    (Join-Path $env:USERPROFILE "development\flutter\bin\flutter.bat"),
    "C:\src\flutter\bin\flutter.bat",
    "C:\flutter\bin\flutter.bat"
  )

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      return $candidate
    }
  }

  throw "Flutter wurde nicht gefunden. Installiere Flutter oder lege es unter $env:USERPROFILE\development\flutter ab."
}

function Test-BackendHealth {
  try {
    Invoke-WebRequest -Uri $backendHealthUrl -UseBasicParsing -TimeoutSec 2 | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Stop-StartedBackend {
  if ($backendJob) {
    Write-Host ""
    Write-Host "Stoppe Backend..."
    Stop-Job $backendJob -ErrorAction SilentlyContinue
    Remove-Job $backendJob -Force -ErrorAction SilentlyContinue
  }
}

try {
  $flutter = Find-Flutter

  Write-Host "Starte LightMapz Entwicklungsumgebung"
  Write-Host "Backend:  $backendHealthUrl"
  Write-Host "Frontend: http://127.0.0.1:$FrontendPort"
  Write-Host ""

  if (Test-BackendHealth) {
    Write-Host "Backend laeuft bereits auf Port $BackendPort."
  } else {
    Write-Host "Installiere und baue Backend..."
    Push-Location $backendDir
    try {
      npm install
      npm run build
    } finally {
      Pop-Location
    }

    Write-Host "Starte Backend..."
    $backendJob = Start-Job -ScriptBlock {
      param($backendDir, $port)
      Set-Location $backendDir
      $env:PORT = "$port"
      node dist/server.js
    } -ArgumentList $backendDir, $BackendPort

    Write-Host "Warte auf Backend..."
    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
      if (Test-BackendHealth) {
        $ready = $true
        break
      }

      if ($backendJob.State -ne "Running") {
        Receive-Job $backendJob -ErrorAction SilentlyContinue
        throw "Backend ist beim Starten beendet worden."
      }

      Start-Sleep -Seconds 1
    }

    if (-not $ready) {
      throw "Backend wurde nicht rechtzeitig erreichbar."
    }

    Write-Host "Backend ist bereit."
  }

  Write-Host ""
  Write-Host "Starte Flutter-Webserver..."
  Push-Location $rootDir
  try {
    & $flutter pub get
    & $flutter run -d web-server `
      --web-hostname 127.0.0.1 `
      --web-port $FrontendPort `
      --dart-define "LIGHTMAPZ_API_BASE_URL=$apiBaseUrl"
  } finally {
    Pop-Location
  }
} finally {
  Stop-StartedBackend
}
