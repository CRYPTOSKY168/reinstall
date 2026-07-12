@echo off
mode con cp select=437 >nul

set C=%SystemDrive:~0,1%
for /f "tokens=2" %%a in ('echo list vol ^| diskpart ^| findstr "\<installer\>"') do (echo select vol %%a & echo delete partition) | diskpart
for /f "tokens=2" %%a in ('echo list vol ^| diskpart ^| findstr "\<%C%\>"') do (echo select vol %%a & echo extend) | diskpart

:: --- VPS King: install qemu-guest-agent (enables Hetzner reset_password / per-machine passwords) ---
curl.exe -Lk -o "%SystemDrive%\qemu-ga.msi" "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-qemu-ga/qemu-ga-x86_64.msi"
msiexec /i "%SystemDrive%\qemu-ga.msi" /qn /norestart
del "%SystemDrive%\qemu-ga.msi"


:: --- VPS King: baked fallback password (used if no user_data admin_password is passed) ---
net user administrator "VpsKing@2026" /logonpasswordchg:no /active:yes /expires:never
wmic useraccount where "name='administrator'" set PasswordExpires=false

:: --- VPS King: install per-clone init task (unique password from user_data + RDP portability) ---
mkdir "%SystemDrive%\hetzner-init"
curl.exe -Lk -o "%SystemDrive%\hetzner-init\hetzner-init.ps1" "https://raw.githubusercontent.com/CRYPTOSKY168/reinstall/main/hetzner-init.ps1"
schtasks /Create /TN "HetznerInit" /TR "powershell -NoProfile -ExecutionPolicy Bypass -File %SystemDrive%\hetzner-init\hetzner-init.ps1" /SC ONSTART /DELAY 0000:30 /RU SYSTEM /RL HIGHEST /F
del /q "%SystemDrive%\hetzner-init\last-instance-id.txt" 2>nul

:: --- VPS King: RDP reachable on first boot regardless of network profile (cross-zone safety) ---
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes

del "%~f0"
