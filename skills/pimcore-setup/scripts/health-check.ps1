# Read-only five-level health check for a Pimcore project (Windows PowerShell 5.1 or 7).
# Same checks as health-check.sh. Secrets from .pimcore-setup\secrets.env are masked in output.
# Exit 0 only if checks 1-4 pass.
# Usage: powershell -ExecutionPolicy Bypass -File health-check.ps1 -Dir <project> [-Runtime docker|native] [-Url http://localhost:8080] [-PhpService php] [-Json]
param([string]$Dir = '.', [string]$Runtime = '', [string]$Url = '', [string]$PhpService = 'php', [switch]$Json)

if (-not (Test-Path $Dir -PathType Container)) { Write-Error "project folder not found: $Dir"; exit 2 }
Set-Location $Dir
$Url = $Url.TrimEnd('/')
$composeFile = @('docker-compose.yaml', 'docker-compose.yml', 'compose.yaml', 'compose.yml') | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Runtime) {
  $Runtime = 'native'
  if ($composeFile -and (Get-Command docker -ErrorAction SilentlyContinue)) {
    $id = (& docker compose ps -q $PhpService 2>$null); if ($id) { $Runtime = 'docker' }
  }
}

$masks = @()
if (Test-Path '.pimcore-setup/secrets.env') {
  foreach ($l in Get-Content '.pimcore-setup/secrets.env') { if ($l -match '^[A-Z_]*PASSWORD[A-Z_]*=(.+)$') { $masks += $Matches[1] } }
}
function Mask([string]$s) { foreach ($m in $masks) { $s = $s.Replace($m, '****') }; $s }
function Invoke-PConsole([string[]]$a) {
  if ($Runtime -eq 'docker') { $o = & docker compose exec -T $PhpService php bin/console @a 2>&1 }
  else { $o = & php bin/console @a 2>&1 }
  [pscustomobject]@{ ok = ($LASTEXITCODE -eq 0); text = ($o | Out-String) }
}
function Num([string]$t) { $n = $null; foreach ($l in ($t -split "`r?`n")) { if ($l -match '^[\s|]*(\d+)[\s|]*$') { $n = [int]$Matches[1] } }; $n }
$R = @{}; $E = @{}
function SetR($i, $r, $e) { $R[$i] = $r; $e = (Mask $e) -replace "[`r`n]+", ' '; $E[$i] = $e.Substring(0, [Math]::Min(160, $e.Length)) }

# 1 Installation completed
if (-not (Test-Path composer.json)) { SetR 1 'fail' 'no composer.json' }
elseif (-not (Test-Path vendor) -and $Runtime -eq 'native') { SetR 1 'fail' 'vendor/ missing (run composer install)' }
else {
  $v = Invoke-PConsole @('--version', '--no-ansi')
  if ($v.ok) {
    $ver = 'unknown'
    if (Test-Path composer.lock) { $pk = (Get-Content composer.lock -Raw | ConvertFrom-Json).packages | Where-Object name -eq 'pimcore/pimcore'; if ($pk) { $ver = $pk.version } }
    if (Test-Path 'config/local/database.yaml') { SetR 1 'pass' "console runs; pimcore $ver" }
    else { SetR 1 'fail' 'console runs but no config/local/database.yaml (installer not run?)' }
  } else { SetR 1 'fail' ("bin/console failed: " + ($v.text.Trim() -split "`n")[-1]) }
}

# 2 Database initialized
if ($R[1] -ne 'pass') { SetR 2 'skipped' 'depends on #1' }
else {
  $t = Invoke-PConsole @('dbal:run-sql', 'SELECT COUNT(*) AS c FROM information_schema.tables WHERE table_schema = DATABASE()', '--no-ansi')
  $u = Invoke-PConsole @('dbal:run-sql', "SELECT COUNT(*) AS c FROM users WHERE type = 'user' AND admin = 1", '--no-ansi')
  $tables = if ($t.ok) { Num $t.text } else { $null }
  $admins = if ($u.ok) { Num $u.text } else { $null }
  if ($null -eq $tables) { SetR 2 'fail' ("query failed: " + ($t.text.Trim() -split "`n")[-1]) }
  elseif ($tables -gt 20 -and $admins -ge 1) { SetR 2 'pass' "$tables tables, $admins admin user(s)" }
  else { SetR 2 'fail' "$tables tables, admin users: $admins" }
}

if (-not $Url -and $Runtime -eq 'docker') {
  $hp = (& docker compose port nginx 80 2>$null | Select-Object -First 1); if ($hp) { $Url = 'http://localhost:' + ($hp -split ':')[-1] }
}
function Get-Http($u) {
  try { $sw = [Diagnostics.Stopwatch]::StartNew(); $r = Invoke-WebRequest -Uri $u -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 20 -ErrorAction Stop; [pscustomobject]@{ code = [int]$r.StatusCode; body = $r.Content; t = $sw.Elapsed.TotalSeconds } }
  catch { $c = 0; if ($_.Exception.Response) { $c = [int]$_.Exception.Response.StatusCode }; [pscustomobject]@{ code = $c; body = ''; t = 0 } }
}

# 3 Application healthy
if ($R[1] -ne 'pass') { SetR 3 'skipped' 'depends on #1' }
elseif (-not $Url) { SetR 3 'skipped' 'no URL known (pass -Url)' }
else {
  $h = Get-Http "$Url/"
  if (@(200, 301, 302, 303, 404) -contains $h.code -and $h.body -notmatch 'fatal error|stack trace') { SetR 3 'pass' ("GET / $($h.code) in {0:N2}s" -f $h.t) }
  else { SetR 3 'fail' "GET / $($h.code)" }
}

# 4 Admin accessible
if ($R[3] -ne 'pass') { SetR 4 'skipped' 'depends on #3' }
else {
  $h = Get-Http "$Url/admin/login"
  if ($h.code -eq 200 -and $h.body -match 'password') { SetR 4 'pass' 'GET /admin/login 200, login form found' } else { SetR 4 'fail' "GET /admin/login $($h.code)" }
}

# 5 Optional services
$opt = ''; $ofail = $false
if ($Runtime -eq 'docker') {
  foreach ($s in (& docker compose config --services 2>$null)) {
    $st = (& docker compose ps --format '{{.State}}' $s 2>$null | Select-Object -First 1); if (-not $st) { $st = 'not running' }
    $opt += "${s}:$st "
    if (@('redis', 'supervisord', 'opensearch', 'elasticsearch', 'mailpit', 'mailhog') -contains $s -and $st -ne 'running') { $ofail = $true }
  }
} else {
  $here = (Get-Location).Path
  $w = Get-CimInstance Win32_Process -Filter "Name like 'php%'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'messenger:consume' -and $_.CommandLine -match [regex]::Escape($here) }
  if ($w) { $opt += 'workers:running' } else { $opt += 'workers:not running'; $ofail = $true }
}
if (-not $opt) { SetR 5 'skipped' 'nothing to check' } elseif ($ofail) { SetR 5 'fail' $opt } else { SetR 5 'pass' $opt }

$names = @{ 1 = 'Installation completed'; 2 = 'Database initialized'; 3 = 'Application healthy'; 4 = 'Admin accessible'; 5 = 'Optional services' }
if ($Json) {
  [ordered]@{ runtime = $Runtime; url = $Url; checks = @(1..5 | ForEach-Object { [ordered]@{ id = $_; name = $names[$_]; result = $R[$_]; evidence = $E[$_] } }) } | ConvertTo-Json -Depth 4
} else {
  "runtime: $Runtime   url: $(if ($Url) { $Url } else { 'unknown' })"
  '{0,-2} {1,-24} {2,-8} {3}' -f '#', 'Check', 'Result', 'Evidence'
  foreach ($i in 1..5) { '{0,-2} {1,-24} {2,-8} {3}' -f $i, $names[$i], $R[$i], $E[$i] }
}
foreach ($i in 1..4) { if ($R[$i] -ne 'pass') { exit 1 } }
exit 0
