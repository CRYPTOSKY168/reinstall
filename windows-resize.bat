@echo off
mode con cp select=437 >nul

set C=%SystemDrive:~0,1%
for /f "tokens=2" %%a in ('echo list vol ^| diskpart ^| findstr "\<installer\>"') do (echo select vol %%a & echo delete partition) | diskpart
for /f "tokens=2" %%a in ('echo list vol ^| diskpart ^| findstr "\<%C%\>"') do (echo select vol %%a & echo extend) | diskpart

:: --- VPS King: install qemu-guest-agent (enables Hetzner reset_password / per-machine passwords) ---
curl.exe -Lk -o "%SystemDrive%\qemu-ga.msi" "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-qemu-ga/qemu-ga-x86_64.msi"
msiexec /i "%SystemDrive%\qemu-ga.msi" /qn /norestart
del "%SystemDrive%\qemu-ga.msi"


:: --- VPS King: guarantee admin password works (clear must-change/expire flags) ---
net user administrator "VpsKing@2026" /logonpasswordchg:no /active:yes /expires:never
wmic useraccount where "name='administrator'" set PasswordExpires=false


:: --- VPS King: sysprep on next boot -> portable image (any CPU/location) ---
curl.exe -Lk -o "%SystemRoot%\System32\Sysprep\vpsking-unattend.xml" "https://raw.githubusercontent.com/CRYPTOSKY168/reinstall/main/vpsking-sysprep-unattend.xml"
(echo schtasks /delete /tn vpsking-sysprep /f
echo %SystemRoot%\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:%SystemRoot%\System32\Sysprep\vpsking-unattend.xml) > %SystemDrive%\vpsking-sysprep.bat
schtasks /create /tn "vpsking-sysprep" /ru SYSTEM /rl HIGHEST /sc onstart /f /tr "%SystemDrive%\vpsking-sysprep.bat"

del "%~f0"
shutdown /r /t 15
