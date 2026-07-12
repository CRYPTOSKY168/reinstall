# VPS King — per-clone init (runs at every boot via HetznerInit scheduled task)
# 1) every boot: keep RDP reachable even if NIC re-homed to a new profile (fixes cross-zone US boot)
# 2) once per new clone (gated by Hetzner instance-id): set unique Administrator password from user_data
$ErrorActionPreference = 'SilentlyContinue'

# --- (1) RDP portability: enable RDP + firewall + force network profile to Private ---
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f | Out-Null
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes | Out-Null
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue

# --- (2) unique password from user_data, once per instance-id ---
$stateFile = 'C:\hetzner-init\last-instance-id.txt'
$mdUrl = 'http://169.254.169.254/hetzner/v1/metadata'
$udUrl = 'http://169.254.169.254/hetzner/v1/userdata'

$md = $null
for ($i = 0; $i -lt 30 -and -not $md; $i++) {
    try { $md = (Invoke-WebRequest -Uri $mdUrl -UseBasicParsing -TimeoutSec 5).Content } catch { Start-Sleep 5 }
}
if (-not $md) { exit 0 }

$instanceId = ([regex]::Match($md, '(?m)^instance-id:\s*(\S+)')).Groups[1].Value
if (-not $instanceId) { exit 0 }

$last = ''
if (Test-Path $stateFile) { $last = (Get-Content $stateFile -Raw).Trim() }
if ($instanceId -eq $last) { exit 0 }   # already applied for this clone -> no-op on reboots

$ud = ''
try { $ud = (Invoke-WebRequest -Uri $udUrl -UseBasicParsing -TimeoutSec 10).Content } catch {}
$pw = ([regex]::Match($ud, '(?m)^admin_password:\s*(.+)$')).Groups[1].Value.Trim()

if ($pw) {
    net user Administrator "$pw"
    net user Administrator /active:yes
    wmic useraccount where "name='Administrator'" set PasswordExpires=false | Out-Null
}

New-Item -ItemType Directory -Force -Path (Split-Path $stateFile) | Out-Null
Set-Content -Path $stateFile -Value $instanceId
