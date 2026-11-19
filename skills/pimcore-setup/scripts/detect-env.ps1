# Read-only environment detection for /pimcore-setup on Windows (PowerShell 5.1 or 7).
# Prints JSON with the same keys as detect-env.sh. Changes nothing.
# Usage: powershell -ExecutionPolicy Bypass -File detect-env.ps1 [-Dir <target>]
param([string]$Dir = ".")

function Tool($name) { $c = Get-Command $name -ErrorAction SilentlyContinue; if ($c) { $c } else { $null } }
function Run($exe, $argList) { try { (& $exe @argList 2>$null | Out-String).Trim() } catch { "" } }

$warn = @()
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$arch = $env:PROCESSOR_ARCHITECTURE

$docker = [ordered]@{ installed = $false; version = $null; daemonRunning = $false; composeV2 = $null; composeV1Present = $false }
if (Tool docker) {
  $docker.installed = $true
  $docker.version = Run docker @('version', '--format', '{{.Client.Version}}')
  & docker info *> $null; if ($LASTEXITCODE -eq 0) { $docker.daemonRunning = $true }
  $cv = Run docker @('compose', 'version', '--short'); if ($cv) { $docker.composeV2 = $cv }
  if (-not $docker.daemonRunning) { $warn += 'docker installed but daemon not reachable (start Docker Desktop)' }
  if (-not $docker.composeV2) { $warn += 'docker compose v2 missing' }
}
if (Tool docker-compose) { $docker.composeV1Present = $true }

$wsl = $null
if (Tool wsl) { $wsl = (Run wsl @('--status')) -replace "`0", '' }

$php = [ordered]@{ version = $null; extensions = $null }
if (Tool php) {
  $php.version = Run php @('-r', 'echo PHP_VERSION;')
  $php.extensions = ((Run php @('-m')) -split "`r?`n" | Where-Object { $_ -and $_ -notmatch '^\[' } | ForEach-Object { $_.ToLower() } | Sort-Object -Unique) -join ','
}

$ports = [ordered]@{}
$listening = @()
try { $listening = (Get-NetTCPConnection -State Listen -ErrorAction Stop).LocalPort } catch {
  $listening = (netstat -an | Select-String 'LISTENING' | ForEach-Object { ($_ -split '\s+')[2] -replace '.*:', '' })
}
foreach ($p in 80, 443, 3306, 6379, 8080, 8025) { $ports["$p"] = if ($listening -contains $p -or $listening -contains "$p") { 'in use' } else { 'free' } }

$abs = [System.IO.Path]::GetFullPath($Dir)
$target = [ordered]@{ path = $abs; exists = $false; empty = $false; isPimcore = $false; onWindowsMount = $false }
if (Test-Path $abs -PathType Container) {
  $target.exists = $true
  $target.empty = -not (Get-ChildItem -Force $abs | Select-Object -First 1)
  $cj = Join-Path $abs 'composer.json'
  if ((Test-Path $cj) -and (Select-String -Path $cj -Pattern '"pimcore/(pimcore|skeleton|demo)"' -Quiet)) { $target.isPimcore = $true }
}
if ($abs -match ' ') { $warn += 'target path contains spaces' }
if ($arch -match 'ARM') { $warn += 'ARM CPU: confirm the Docker image tags support arm64' }
if (-not (Tool wsl)) { $warn += 'WSL not found: Pimcore development on Windows needs WSL2 or Docker Desktop with the WSL2 backend' }

$drive = (Get-Item $(if ($target.exists) { $abs } else { Split-Path $abs -Parent }) -ErrorAction SilentlyContinue).PSDrive
$out = [ordered]@{
  os = 'windows'
  osDetail = if ($os) { "$($os.Caption) $($os.Version)" } else { $null }
  arch = $arch
  cpus = [Environment]::ProcessorCount
  memGB = if ($cs) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) } else { $null }
  diskFreeGB = if ($drive) { [math]::Round($drive.Free / 1GB, 1) } else { $null }
  wsl = $wsl
  docker = $docker
  php = $php
  composer = if (Tool composer) { ((Run composer @('--version', '--no-ansi')) -split ' ')[2] } else { $null }
  mysqlClient = if (Tool mariadb) { Run mariadb @('--version') } elseif (Tool mysql) { Run mysql @('--version') } else { $null }
  symfonyCli = if (Tool symfony) { Run symfony @('version', '--no-ansi') } else { $null }
  git = if (Tool git) { ((Run git @('--version')) -split ' ')[2] } else { $null }
  node = if (Tool node) { Run node @('--version') } else { $null }
  ports = $ports
  target = $target
  warnings = $warn
}
$out | ConvertTo-Json -Depth 4
