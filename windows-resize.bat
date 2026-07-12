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

:: --- VPS King: OpenSSH server (customer feature + lets us verify/debug the image) ---
curl.exe -Lk -o "%SystemDrive%\openssh.zip" "https://github.com/PowerShell/Win32-OpenSSH/releases/latest/download/OpenSSH-Win64.zip"
powershell -NoProfile -ExecutionPolicy Bypass -Command "try{ Expand-Archive -Force '%SystemDrive%\openssh.zip' '%ProgramFiles%'; & '%ProgramFiles%\OpenSSH-Win64\install-sshd.ps1'; New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null; Set-Service sshd -StartupType Automatic; Start-Service sshd }catch{}"
del "%SystemDrive%\openssh.zip"

:: --- VPS King: install per-clone init task (unique password from user_data + RDP portability) ---
mkdir "%SystemDrive%\hetzner-init" 2>nul
set "LOG=%SystemDrive%\hetzner-init\install-log.txt"
echo [%date% %time%] windows-resize.bat start > "%LOG%"

curl.exe -Lk -o "%SystemDrive%\hetzner-init\hetzner-init.ps1" "https://raw.githubusercontent.com/CRYPTOSKY168/reinstall/main/hetzner-init.ps1"
if exist "%SystemDrive%\hetzner-init\hetzner-init.ps1" (echo [OK] downloaded hetzner-init.ps1 via curl >> "%LOG%") else (echo [FAIL] curl - trying certutil >> "%LOG%" & certutil -urlcache -split -f "https://raw.githubusercontent.com/CRYPTOSKY168/reinstall/main/hetzner-init.ps1" "%SystemDrive%\hetzner-init\hetzner-init.ps1" >> "%LOG%" 2>&1)

:: robust task creation (Register-ScheduledTask fires ONSTART as SYSTEM more reliably than schtasks)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\hetzner-init\hetzner-init.ps1'; $t=New-ScheduledTaskTrigger -AtStartup; $t.Delay='PT30S'; $p=New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest; Register-ScheduledTask -TaskName 'HetznerInit' -Action $a -Trigger $t -Principal $p -Force | Out-Null" >> "%LOG%" 2>&1
echo [%date% %time%] Register-ScheduledTask exit=%errorlevel% >> "%LOG%"
schtasks /query /TN "HetznerInit" >> "%LOG%" 2>&1
del /q "%SystemDrive%\hetzner-init\last-instance-id.txt" 2>nul

:: --- VPS King: RDP reachable on first boot regardless of network profile (cross-zone safety) ---
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f >> "%LOG%" 2>&1
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes >> "%LOG%" 2>&1
echo [%date% %time%] windows-resize.bat done >> "%LOG%"

del "%~f0"
