# VPS King — per-clone init (runs every boot via HetznerInit task). Logs to C:\hetzner-init\log.txt
$ErrorActionPreference = 'SilentlyContinue'
$log = 'C:\hetzner-init\log.txt'
function L($m) { try { Add-Content -Path $log -Value ("{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) } catch {} }
New-Item -ItemType Directory -Force -Path 'C:\hetzner-init' | Out-Null
L "=== HetznerInit run start ==="

# --- (1) RDP portability: enable RDP + firewall + force network profile Private (cross-zone fix) ---
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f | Out-Null
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes | Out-Null
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue
L "RDP+firewall+profile applied"

# --- (2) unique password from user_data, once per instance-id ---
$stateFile = 'C:\hetzner-init\last-instance-id.txt'
# ensure route to link-local metadata exists
$gw = (Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway} | Select-Object -First 1).IPv4DefaultGateway.NextHop
if ($gw) { route add 169.254.169.254 mask 255.255.255.255 $gw metric 1 | Out-Null; L "route to metadata via $gw" }

$md = $null
foreach ($base in @('http://169.254.169.254/hetzner/v1','http://169.254.169.254/latest')) {
    for ($i = 0; $i -lt 20 -and -not $md; $i++) {
        try { $md = (Invoke-WebRequest -Uri "$base/metadata" -UseBasicParsing -TimeoutSec 5).Content } catch { Start-Sleep 5 }
    }
    if ($md) { $mdBase = $base; break }
}
if (-not $md) { L "metadata FETCH FAILED (both endpoints)"; L "=== end (no metadata) ==="; exit 0 }
L "metadata OK from $mdBase (len=$($md.Length))"

$instanceId = ([regex]::Match($md, '(?m)^instance-id:\s*(\S+)')).Groups[1].Value
if (-not $instanceId) { $instanceId = ([regex]::Match($md, '(?m)^instance_id:\s*(\S+)')).Groups[1].Value }
L "instance-id=$instanceId"
if (-not $instanceId) { L "no instance-id in metadata"; exit 0 }

$last = ''
if (Test-Path $stateFile) { $last = (Get-Content $stateFile -Raw).Trim() }
if ($instanceId -eq $last) { L "already applied for $instanceId -> skip"; exit 0 }

$udBase = if ($mdBase -like '*hetzner*') { "$mdBase/userdata" } else { "$mdBase/user-data" }
$ud = ''
try { $ud = (Invoke-WebRequest -Uri $udBase -UseBasicParsing -TimeoutSec 10).Content } catch { L "userdata fetch err" }
$pw = ([regex]::Match($ud, '(?m)^admin_password:\s*(.+)$')).Groups[1].Value.Trim()
L "userdata len=$($ud.Length) pw_found=$([bool]$pw)"

if ($pw) {
    net user Administrator "$pw"
    net user Administrator /active:yes
    wmic useraccount where "name='Administrator'" set PasswordExpires=false | Out-Null
    L "Administrator password SET from user_data"
} else {
    L "no admin_password in user_data -> keep baked"
}

Set-Content -Path $stateFile -Value $instanceId
L "=== end (applied $instanceId) ==="
