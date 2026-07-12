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
mkdir "%SystemDrive%\hetzner-init" 2>nul
set "LOG=%SystemDrive%\hetzner-init\install-log.txt"
echo [%date% %time%] windows-resize.bat start > "%LOG%"

curl.exe -Lk -o "%SystemDrive%\hetzner-init\hetzner-init.ps1" "https://raw.githubusercontent.com/CRYPTOSKY168/reinstall/main/hetzner-init.ps1"
if exist "%SystemDrive%\hetzner-init\hetzner-init.ps1" (echo [OK] downloaded hetzner-init.ps1 via curl >> "%LOG%") else (echo [FAIL] curl - trying certutil >> "%LOG%" & certutil -urlcache -split -f "https://raw.githubusercontent.com/CRYPTOSKY168/reinstall/main/hetzner-init.ps1" "%SystemDrive%\hetzner-init\hetzner-init.ps1" >> "%LOG%" 2>&1)

schtasks /Create /TN "HetznerInit" /TR "powershell -NoProfile -ExecutionPolicy Bypass -File %SystemDrive%\hetzner-init\hetzner-init.ps1" /SC ONSTART /DELAY 0000:30 /RU SYSTEM /RL HIGHEST /F >> "%LOG%" 2>&1
echo [%date% %time%] schtasks create exit=%errorlevel% >> "%LOG%"
schtasks /query /TN "HetznerInit" >> "%LOG%" 2>&1
del /q "%SystemDrive%\hetzner-init\last-instance-id.txt" 2>nul

:: --- VPS King: RDP reachable on first boot regardless of network profile (cross-zone safety) ---
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f >> "%LOG%" 2>&1
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes >> "%LOG%" 2>&1
echo [%date% %time%] windows-resize.bat done >> "%LOG%"

del "%~f0"
