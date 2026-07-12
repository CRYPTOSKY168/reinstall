@echo off
mode con cp select=437 >nul

set C=%SystemDrive:~0,1%
for /f "tokens=2" %%a in ('echo list vol ^| diskpart ^| findstr "\<installer\>"') do (echo select vol %%a & echo delete partition) | diskpart
for /f "tokens=2" %%a in ('echo list vol ^| diskpart ^| findstr "\<%C%\>"') do (echo select vol %%a & echo extend) | diskpart

:: --- VPS King: install qemu-guest-agent (enables Hetzner reset_password / per-machine passwords) ---
curl.exe -Lk -o "%SystemDrive%\qemu-ga.msi" "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-qemu-ga/qemu-ga-x86_64.msi"
msiexec /i "%SystemDrive%\qemu-ga.msi" /qn /norestart
del "%SystemDrive%\qemu-ga.msi"

del "%~f0"
