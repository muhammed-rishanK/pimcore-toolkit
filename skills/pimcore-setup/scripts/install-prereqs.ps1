# Installs the prerequisites for the Docker route on Windows: WSL2 and Docker Desktop.
# Usage: install-prereqs.ps1 [-Check]
#   -Check   report what is missing and what would be installed; change nothing
# Uses winget. Windows shows its own administrator (UAC) prompt for the install; that
# prompt belongs to Windows and is never bypassed. A restart may be required.
# Output: one JSON object. status is one of: ready, restart_required, failed.
param([switch]$Check)
$ErrorActionPreference = 'Continue'

function Has($n) { [bool](Get-Command $n -ErrorAction SilentlyContinue) }
function DockerOk { if (-not (Has docker)) { return $false }; docker info 2>$null | Out-Null; return ($LASTEXITCODE -eq 0) }

$steps = @(); $status = 'ready'; $note = ''
$dockerInstalled = Has docker
$wslText = ''
if (Has wsl) { $wslText = (wsl --status 2>&1 | Out-String) -replace "`0", '' }
$wslReady = (Has wsl) -and ($wslText -match 'Default Version|Standardversion|WSL 2|Versi') -and ($wslText -notmatch 'not installed|install')
$needWsl = -not $wslReady
$needDocker = -not $dockerInstalled

if ($Check) {
    [pscustomobject]@{ status = 'check'; needWsl = $needWsl; needDocker = $needDocker; winget = (Has winget) } | ConvertTo-Json -Compress
    exit 0
}

if (-not (Has winget)) {
    [pscustomobject]@{ status = 'failed'; note = 'winget not found. Install "App Installer" from the Microsoft Store, then run again.'; steps = @() } | ConvertTo-Json -Compress
    exit 1
}

if ($needWsl) {
    # wsl --install needs elevation; Start-Process -Verb RunAs shows the normal Windows prompt.
    try {
        $p = Start-Process -FilePath wsl.exe -ArgumentList '--install', '--no-distribution' -Verb RunAs -Wait -PassThru
        $steps += "wsl --install --no-distribution (exit $($p.ExitCode))"
        $status = 'restart_required'
        $note = 'WSL2 was installed. Windows needs a restart before Docker can use it.'
    } catch {
        $status = 'failed'; $note = 'The administrator prompt was declined or WSL install failed: ' + $_.Exception.Message
    }
}

if ($status -ne 'failed' -and $needDocker) {
    winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --silent | Out-Null
    $steps += "winget install Docker.DockerDesktop (exit $LASTEXITCODE)"
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { $status = 'failed'; $note = 'Docker Desktop install did not finish (winget exit ' + $LASTEXITCODE + ').' }
    elseif ($status -ne 'restart_required') { $status = 'restart_required'; $note = 'Docker Desktop was installed. Restart Windows once, then run the same command again.' }
}

if ($status -eq 'ready') {
    # Everything is installed and no restart is pending: start Docker Desktop and wait for the daemon.
    if (-not (DockerOk)) {
        $exe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
        if (Test-Path $exe) { Start-Process $exe | Out-Null; $steps += 'started Docker Desktop' }
        for ($i = 0; $i -lt 60 -and -not (DockerOk); $i++) { Start-Sleep -Seconds 5 }
    }
    if (-not (DockerOk)) { $status = 'failed'; $note = 'Docker Desktop did not become ready in 5 minutes. Open it once to accept its terms, then run again.' }
}

[pscustomobject]@{ status = $status; note = $note; steps = $steps } | ConvertTo-Json -Compress
if ($status -eq 'failed') { exit 1 } else { exit 0 }
