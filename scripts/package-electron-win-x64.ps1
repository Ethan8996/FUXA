[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipInstall,
    [switch]$SkipBuild,
    [switch]$SkipAppDeps,
    [string]$ElectronDist,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Show-Usage {
    @"
Usage: powershell -ExecutionPolicy Bypass -File .\scripts\package-electron-win-x64.ps1 [options]

Build the FUXA Electron Windows x64 installer by replaying the current
GitHub Actions workflow locally.

Options:
  -DryRun         Print the steps without executing them.
  -SkipInstall    Skip all npm install steps.
  -SkipBuild      Skip the Angular production build.
  -SkipAppDeps    Skip electron-builder install-app-deps.
  -ElectronDist   Directory containing electron-v39.8.6-win32-x64.zip or
                  another matching Electron zip for the configured version.
  -Help           Show this help message.

Notes:
  - This script stages build inputs into app/electron/server and
    app/electron/client/dist, matching .github/workflows/electron_latest.yml.
  - Use Node.js 18 on Windows for the most reliable Windows NSIS build.
"@
}

if ($Help) {
    Show-Usage
    exit 0
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

if ($ElectronDist) {
    if (-not (Test-Path -Path $ElectronDist -PathType Container)) {
        throw "ElectronDist directory does not exist: $ElectronDist"
    }

    $ElectronDist = (Resolve-Path -Path $ElectronDist).Path
}

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Display,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    if ($DryRun) {
        Write-Host "[dry-run] $Display"
        return
    }

    Write-Host ">>> $Display"
    & $Action
}

function Invoke-InRepo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Display,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    $innerAction = $Action
    Invoke-Step -Display $Display -Action {
        Push-Location $RepoRoot
        try {
            & $innerAction
        }
        finally {
            Pop-Location
        }
    }
}

$electronServerDir = Join-Path $RepoRoot 'app\electron\server'
$electronClientDistDir = Join-Path $RepoRoot 'app\electron\client\dist'

if (-not $SkipInstall) {
    Invoke-InRepo -Display 'cd server && npm install' -Action {
        Set-Location (Join-Path $RepoRoot 'server')
        npm install
    }

    Invoke-InRepo -Display 'cd client && npm install' -Action {
        Set-Location (Join-Path $RepoRoot 'client')
        npm install
    }

    Invoke-InRepo -Display 'cd app/electron && npm install' -Action {
        Set-Location (Join-Path $RepoRoot 'app\electron')
        npm install
    }
}

if (-not $SkipBuild) {
    Invoke-InRepo -Display 'cd client && npm run build -- --configuration=production' -Action {
        Set-Location (Join-Path $RepoRoot 'client')
        npm run build -- --configuration=production
    }
}

Invoke-InRepo -Display 'Reset app/electron staging directories' -Action {
    if (Test-Path $electronServerDir) {
        Remove-Item -Recurse -Force $electronServerDir
    }
    if (Test-Path $electronClientDistDir) {
        Remove-Item -Recurse -Force $electronClientDistDir
    }
    New-Item -ItemType Directory -Force -Path $electronServerDir | Out-Null
    New-Item -ItemType Directory -Force -Path $electronClientDistDir | Out-Null
}

Invoke-InRepo -Display 'Copy server to app/electron/server' -Action {
    Copy-Item -Path (Join-Path $RepoRoot 'server\*') -Destination $electronServerDir -Recurse -Force
}

Invoke-InRepo -Display 'Copy client/dist to app/electron/client/dist' -Action {
    Copy-Item -Path (Join-Path $RepoRoot 'client\dist\*') -Destination $electronClientDistDir -Recurse -Force
}

if (-not $SkipAppDeps) {
    Invoke-InRepo -Display 'cd app/electron && npx electron-builder install-app-deps' -Action {
        Set-Location (Join-Path $RepoRoot 'app\electron')
        npx electron-builder install-app-deps
    }
}

$builderArgs = @('--win', 'nsis', '--x64')
if ($ElectronDist) {
    $builderArgs += "-c.electronDist=$ElectronDist"
}
$builderCommandDisplay = 'cd app/electron && npx electron-builder ' + ($builderArgs -join ' ')

Invoke-InRepo -Display $builderCommandDisplay -Action {
    Set-Location (Join-Path $RepoRoot 'app\electron')
    & npx electron-builder @builderArgs
}
