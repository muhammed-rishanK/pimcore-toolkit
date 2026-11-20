# Prepares the free Docker route on Windows: WSL2 + Ubuntu + Docker Engine inside Ubuntu.
# Docker Desktop is never installed (it needs a paid licence at larger companies). If a
# working Docker is already on the host (for example Docker Desktop you installed yourself),
# it is used as it is and nothing is installed.
# Usage: install-prereqs.ps1 [-Check] [-Distro Ubuntu] [-User dev]
#   -Check   report what is missing and what would be installed; change nothing
# Windows shows its own administrator (UAC) prompt only when WSL itself must be enabled.
# That prompt belongs to Windows and is never bypassed. A restart is needed after enabling WSL.
# Output: one JSON object. status is one of: ready, restart_required, failed, check.
# On ready: runtime is "wsl" (use: wsl -d <distro> -u <user> ...) or "host-docker".
param([switch]$Check, [string]$Distro = 'Ubuntu', [string]$User = 'dev')
$ErrorActionPreference = 'Continue'

function Has($n) { [bool](Get-Command $n -ErrorAction SilentlyContinue) }
function Clean($s) { return (($s | Out-String) -replace "`0", '') }
function HostDockerOk { if (-not (Has docker)) { return $false }; docker info 2>$null | Out-Null; return ($LASTEXITCODE -eq 0) }
function WslOk {
    if (-not (Has wsl)) { return $false }
    wsl --status 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}
function DistroListed { if (-not (Has wsl)) { return $false }; return ((Clean (wsl -l -q 2>$null)) -split "`r?`n" | ForEach-Object { $_.Trim() }) -contains $Distro }
function DockerInDistro { wsl -d $Distro -u $User -- docker info 2>$null | Out-Null; return ($LASTEXITCODE -eq 0) }
function Out-Json($o, $code) { $o | ConvertTo-Json -Compress; exit $code }

$steps = @()

# 1. A working Docker already on the host: use it, install nothing.
if (HostDockerOk) {
    Out-Json ([pscustomobject]@{ status = 'ready'; runtime = 'host-docker'; note = 'Using the Docker already on this machine; nothing was installed.'; steps = @() }) 0
}

$needWsl = -not (WslOk)
$needDistro = $needWsl -or -not (DistroListed)
$needDocker = $needDistro -or -not (DockerInDistro)

if ($Check) {
    Out-Json ([pscustomobject]@{ status = 'check'; needWsl = $needWsl; needDistro = $needDistro; needDockerEngine = $needDocker; adminPromptNeeded = $needWsl }) 0
}

# 2. WSL2 + Ubuntu. Enabling WSL needs administrator rights (one Windows prompt) and a restart.
if ($needWsl) {
    $tmp = Join-Path $env:TEMP ('pimcore-prereqs-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $scriptFile = Join-Path $tmp 'admin-steps.ps1'
    "wsl.exe --install -d $Distro --no-launch" | Set-Content -Path $scriptFile
    try {
        Start-Process -FilePath powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptFile -Verb RunAs -Wait -WindowStyle Hidden
        $steps += "wsl --install -d $Distro --no-launch (administrator)"
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
        Out-Json ([pscustomobject]@{ status = 'restart_required'; note = 'WSL2 and Ubuntu were installed. Restart Windows once, then run the same command again.'; steps = $steps }) 0
    } catch {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
        Out-Json ([pscustomobject]@{ status = 'failed'; note = ('The administrator prompt was declined: ' + $_.Exception.Message); steps = $steps }) 1
    }
}

# 3. WSL is enabled; make sure the distro is installed (no administrator rights needed).
if (-not (DistroListed)) {
    wsl.exe --install -d $Distro --no-launch | Out-Null
    $steps += "wsl --install -d $Distro --no-launch"
}
if (-not (DistroListed)) {
    $launcher = Get-Command ($Distro.ToLower() + '.exe') -ErrorAction SilentlyContinue
    if ($launcher) { & $launcher.Source install --root | Out-Null; $steps += ($Distro.ToLower() + '.exe install --root') }
}
if (-not (DistroListed)) {
    Out-Json ([pscustomobject]@{ status = 'failed'; note = "The $Distro distro could not be registered. Run 'wsl --install -d $Distro' once yourself, create the user it asks for, then run this command again."; steps = $steps }) 1
}

# 4. Docker Engine inside the distro (free, Apache 2.0). Only done when it is not there yet.
if (-not (DockerInDistro)) {
    $provision = @'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates >/dev/null
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh >/dev/null 2>&1
id __USER__ >/dev/null 2>&1 || useradd -m -s /bin/bash __USER__
usermod -aG docker __USER__
if [ ! -f /etc/wsl.conf ]; then printf '[boot]\nsystemd=true\n' > /etc/wsl.conf; fi
'@
    $provision = ($provision -replace '__USER__', $User) -replace "`r", ''
    $provision | wsl -d $Distro -u root -- bash -s
    $steps += "installed Docker Engine inside $Distro and created user $User"
    wsl --terminate $Distro | Out-Null
    wsl -d $Distro -u root -- sh -c 'systemctl enable --now docker 2>/dev/null || service docker start' | Out-Null
    for ($i = 0; $i -lt 24 -and -not (DockerInDistro); $i++) { Start-Sleep -Seconds 5 }
}

if (-not (DockerInDistro)) {
    Out-Json ([pscustomobject]@{ status = 'failed'; note = "Docker Engine did not answer inside $Distro. Open a '$Distro' terminal and run: sudo service docker start"; steps = $steps }) 1
}
Out-Json ([pscustomobject]@{ status = 'ready'; runtime = 'wsl'; distro = $Distro; user = $User; note = ('Docker Engine runs inside WSL2. Run project commands with: wsl -d ' + $Distro + ' -u ' + $User + ' --cd ~ -- <command>'); steps = $steps }) 0
