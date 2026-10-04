@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Nate the Great's Flashing Tool

:: ============================================================
:: Nate the Great's Flashing Tool
:: Requires adb.exe and fastboot.exe to be in PATH
:: or in the same folder as this BAT file.
:: ============================================================

set "SCRIPT_DIR=%~dp0"
set "ADB=adb"
set "FASTBOOT=fastboot"

:: Prefer adb/fastboot next to this BAT file if present.
if exist "%SCRIPT_DIR%adb.exe" set "ADB=%SCRIPT_DIR%adb.exe"
if exist "%SCRIPT_DIR%fastboot.exe" set "FASTBOOT=%SCRIPT_DIR%fastboot.exe"

:: Make adb/fastboot next to this BAT file available to manual commands too.
set "PATH=%SCRIPT_DIR%;%PATH%"

:START
cls
echo.
echo Welcome to Nate the Great's flashing tool
echo.
echo Press ENTER to start the tool or press ESC to exit the tool
echo.

powershell -NoProfile -Command "$k=[Console]::ReadKey($true); if($k.Key -eq 'Enter'){exit 1}; if($k.Key -eq 'Escape'){exit 2}; exit 0"
if errorlevel 2 goto EXIT
if errorlevel 1 goto MODE_MENU
goto START

:MODE_MENU
cls
echo.
echo Welcome to Nate the Great's flashing tool
echo.
echo If your device is in ADB mode press 1
echo If your device is in ADB Sideload mode press 2
echo If your device is in Bootloader (Fastboot) mode press 3
echo.
choice /c 123 /n /m "Select an option: "

if errorlevel 3 goto FASTBOOT_INITIAL
if errorlevel 2 goto DIRECT_SIDELOAD
if errorlevel 1 goto ADB_MODE
goto MODE_MENU


:: ============================================================
:: ADB MODE
:: ============================================================

:ADB_MODE
cls
echo.
echo Checking for ADB device...
echo.

:ADB_CHECK
set "ADB_FOUND="
set "ADB_UNAUTH="
set "ADB_OFFLINE="

for /f "tokens=1,2" %%A in ('"%ADB%" devices 2^>nul') do (
    if /i "%%B"=="device" set "ADB_FOUND=1"
    if /i "%%B"=="unauthorized" set "ADB_UNAUTH=1"
    if /i "%%B"=="offline" set "ADB_OFFLINE=1"
)

if defined ADB_FOUND goto ADB_DETECTED

if defined ADB_UNAUTH (
    echo Device found but UNAUTHORIZED. Unlock the phone and accept the USB debugging prompt.
    echo.
)
if defined ADB_OFFLINE (
    echo Device found but OFFLINE. Try replugging the cable or toggling USB debugging.
    echo.
)

echo ADB Device not found.....Press Y to retry or N to return to the main menu.
echo.
choice /c YN /n /m "Select: "

if errorlevel 2 goto MODE_MENU
if errorlevel 1 goto ADB_CHECK
goto ADB_MODE

:ADB_DETECTED
echo.
echo ADB device detected.
echo.
echo Rebooting to bootloader mode in 5 seconds..... (PLEASE DO NOT UNPLUG YOUR DEVICE)
timeout /t 5 /nobreak >nul

"%ADB%" reboot bootloader
if errorlevel 1 (
    echo.
    echo Failed to send reboot command.
    pause
    goto MODE_MENU
)

echo.
echo Waiting for Fastboot device...
timeout /t 3 /nobreak >nul
goto FASTBOOT_INITIAL


:: ============================================================
:: DIRECT ADB SIDELOAD MODE
:: ============================================================

:DIRECT_SIDELOAD
cls
echo.
echo Checking for ADB Sideload device...
echo.

:DIRECT_SIDELOAD_CHECK
set "SIDELOAD_FOUND="
set "SIDELOAD_SERIAL="

for /f "tokens=1,2" %%A in ('"%ADB%" devices 2^>nul') do (
    if /i "%%B"=="sideload" (
        set "SIDELOAD_FOUND=1"
        set "SIDELOAD_SERIAL=%%A"
    )
)

if not defined SIDELOAD_FOUND (
    echo ADB Sideload device not found.....Press Y to retry or N to return to the main menu.
    echo.
    choice /c YN /n /m "Select: "
    if errorlevel 2 goto MODE_MENU
    if errorlevel 1 goto DIRECT_SIDELOAD_CHECK
    goto DIRECT_SIDELOAD
)

echo.
echo ADB Sideload device detected: !SIDELOAD_SERIAL!
echo.

set "SideloadFile="
set /p "SideloadFile=Enter filename and extension to sideload: "
if defined SideloadFile set "SideloadFile=!SideloadFile:"=!"

if not defined SideloadFile (
    echo.
    echo No filename entered.
    pause
    goto DIRECT_SIDELOAD
)

if not exist "!SideloadFile!" if exist "%SCRIPT_DIR%!SideloadFile!" set "SideloadFile=%SCRIPT_DIR%!SideloadFile!"
if not exist "!SideloadFile!" (
    echo.
    echo ERROR: File not found: !SideloadFile!
    echo Put it in the current folder or beside this BAT file, or enter the full path.
    pause
    goto DIRECT_SIDELOAD
)

echo.
echo ============================================================
echo Starting ADB sideload...
echo ============================================================
echo.

"%ADB%" sideload "!SideloadFile!"
set "SIDELOAD_RESULT=!errorlevel!"

echo.

if not "!SIDELOAD_RESULT!"=="0" (
    echo ============================================================
    echo ADB sideload reported an error. Error code: !SIDELOAD_RESULT!
    echo ============================================================
    echo.
    choice /c RN /n /m "Press R to retry sideload or N to continue: "

    if errorlevel 2 goto POST_SIDELOAD
    if errorlevel 1 goto DIRECT_SIDELOAD
)

echo.
echo ============================================================
echo ADB sideload completed.
echo ============================================================
echo.

goto POST_SIDELOAD


:: ============================================================
:: INITIAL FASTBOOT FLASH
:: ============================================================

:FASTBOOT_INITIAL
cls
echo.
echo Checking required initial images...
echo.

set "BOOT_IMAGE=boot.img"
set "VENDOR_BOOT_IMAGE=vendor_boot.img"
set "INIT_BOOT_IMAGE=init_boot.img"

if not exist "%BOOT_IMAGE%" if exist "%SCRIPT_DIR%boot.img" set "BOOT_IMAGE=%SCRIPT_DIR%boot.img"
if not exist "%VENDOR_BOOT_IMAGE%" if exist "%SCRIPT_DIR%vendor_boot.img" set "VENDOR_BOOT_IMAGE=%SCRIPT_DIR%vendor_boot.img"
if not exist "%INIT_BOOT_IMAGE%" if exist "%SCRIPT_DIR%init_boot.img" set "INIT_BOOT_IMAGE=%SCRIPT_DIR%init_boot.img"

if not exist "%BOOT_IMAGE%" (
    echo ERROR: boot.img was not found.
    echo Put boot.img in the current folder or beside this BAT file.
    pause
    goto MODE_MENU
)

if not exist "%VENDOR_BOOT_IMAGE%" (
    echo ERROR: vendor_boot.img was not found.
    echo Put vendor_boot.img in the current folder or beside this BAT file.
    pause
    goto MODE_MENU
)

if not exist "%INIT_BOOT_IMAGE%" (
    echo ERROR: init_boot.img was not found.
    echo Put init_boot.img in the current folder or beside this BAT file.
    pause
    goto MODE_MENU
)

echo Required initial images found.
echo.
echo Checking for Fastboot device...
echo.

:FASTBOOT_INITIAL_CHECK
set "FB_FOUND="
set "FB_SERIAL="

for /f "tokens=1,2" %%A in ('"%FASTBOOT%" devices 2^>nul') do (
    if not "%%A"=="" (
        set "FB_FOUND=1"
        set "FB_SERIAL=%%A"
    )
)

if not defined FB_FOUND (
    echo Fastboot device not found.....Press Y to retry or N to return to the main menu.
    echo.
    choice /c YN /n /m "Select: "

    if errorlevel 2 goto MODE_MENU
    if errorlevel 1 goto FASTBOOT_INITIAL_CHECK
    goto FASTBOOT_INITIAL
)

echo.
echo Fastboot device detected: !FB_SERIAL!
echo.
echo This will flash boot_ab, vendor_boot_ab and init_boot_ab using the images found above.
echo Do NOT unplug the device or close this window until it finishes.
echo.
choice /c YN /n /m "Continue? Press Y to flash or N to return to the main menu: "
if errorlevel 2 goto MODE_MENU
echo.

set "FLASH_STEP="
set "FLASH_PROGRESS=none"

echo ============================================================
echo Flashing boot_ab...
echo ============================================================
set "FLASH_STEP=boot_ab"
"%FASTBOOT%" flash boot_ab "%BOOT_IMAGE%"
if errorlevel 1 goto FLASH_ERROR
set "FLASH_PROGRESS=boot_ab"

echo.
echo ============================================================
echo Flashing vendor_boot_ab...
echo ============================================================
set "FLASH_STEP=vendor_boot_ab"
"%FASTBOOT%" flash vendor_boot_ab "%VENDOR_BOOT_IMAGE%"
if errorlevel 1 goto FLASH_ERROR
set "FLASH_PROGRESS=boot_ab, vendor_boot_ab"

echo.
echo ============================================================
echo Flashing init_boot_ab...
echo ============================================================
set "FLASH_STEP=init_boot_ab"
"%FASTBOOT%" flash init_boot_ab "%INIT_BOOT_IMAGE%"
if errorlevel 1 goto FLASH_ERROR
set "FLASH_PROGRESS=boot_ab, vendor_boot_ab, init_boot_ab"

echo.
echo ============================================================
echo All initial images flashed successfully.
echo Rebooting to recovery...
echo ============================================================

set "FLASH_STEP=reboot to recovery"
"%FASTBOOT%" reboot recovery
if errorlevel 1 goto FLASH_ERROR

timeout /t 3 /nobreak >nul

:SIDELOAD_WAIT
cls
echo.
echo Please Select 'Apply Update from ADB' in recovery menu ^& press ENTER
echo.

pause >nul

echo.
echo Waiting for ADB sideload device...
echo.

set /a SL_TRIES=0

:SIDELOAD_CHECK
set "SIDELOAD_FOUND="
set "SIDELOAD_SERIAL="

for /f "tokens=1,2" %%A in ('"%ADB%" devices 2^>nul') do (
    if /i "%%B"=="sideload" (
        set "SIDELOAD_FOUND=1"
        set "SIDELOAD_SERIAL=%%A"
    )
)

if not defined SIDELOAD_FOUND (
    echo ADB Sideload device not found.....Press Y to retry or N to return to the previous menu.
    echo.
    choice /c YN /n /m "Select: "
    if errorlevel 2 goto POST_SIDELOAD
    if errorlevel 1 goto SIDELOAD_CHECK
)

echo.
echo Sideload device detected: !SIDELOAD_SERIAL!
echo.

set "SideloadFile="
set /p "SideloadFile=Enter filename and extension to sideload: "
if defined SideloadFile set "SideloadFile=!SideloadFile:"=!"

if not defined SideloadFile (
    echo.
    echo No filename entered.
    pause
    goto SIDELOAD_WAIT
)

if not exist "!SideloadFile!" if exist "%SCRIPT_DIR%!SideloadFile!" set "SideloadFile=%SCRIPT_DIR%!SideloadFile!"
if not exist "!SideloadFile!" (
    echo.
    echo ERROR: File not found: !SideloadFile!
    echo Put it in the current folder or beside this BAT file, or enter the full path.
    pause
    goto SIDELOAD_WAIT
)

echo.
echo ============================================================
echo Starting ADB sideload...
echo ============================================================
echo.

"%ADB%" sideload "!SideloadFile!"
set "SIDELOAD_RESULT=!errorlevel!"

echo.

if not "!SIDELOAD_RESULT!"=="0" (
    echo ============================================================
    echo ADB sideload reported an error. Error code: !SIDELOAD_RESULT!
    echo ============================================================
    echo.

    choice /c RN /n /m "Press R to retry sideload or N to continue: "

    if errorlevel 2 goto POST_SIDELOAD
    if errorlevel 1 goto SIDELOAD_WAIT
)

echo.
echo ============================================================
echo ADB sideload completed.
echo ============================================================
echo.


:: ============================================================
:: POST SIDELOAD MENU
:: ============================================================

:POST_SIDELOAD
echo Press 1 to install additional images from Fastboot
echo Press 2 to reboot to system and exit
echo Press 3 to exit without rebooting
echo.

choice /c 123 /n /m "Select an option: "

if errorlevel 3 goto EXIT
if errorlevel 2 goto REBOOT_FROM_RECOVERY
if errorlevel 1 goto ADDITIONAL_FASTBOOT
goto POST_SIDELOAD


:: ============================================================
:: ADDITIONAL FASTBOOT
:: ============================================================

:ADDITIONAL_FASTBOOT
cls
echo.
echo Please reboot to bootloader and press ENTER
echo.

pause >nul

echo.
echo Checking for Fastboot device...
echo.

:ADDITIONAL_FASTBOOT_CHECK
set "FB_FOUND="
set "FB_SERIAL="

for /f "tokens=1,2" %%A in ('"%FASTBOOT%" devices 2^>nul') do (
    if not "%%A"=="" (
        set "FB_FOUND=1"
        set "FB_SERIAL=%%A"
    )
)

if not defined FB_FOUND (
    echo Fastboot device not found.....Press Y to retry or N to return to the previous menu.
    echo.

    choice /c YN /n /m "Select: "

    if errorlevel 2 goto POST_SIDELOAD
    if errorlevel 1 goto ADDITIONAL_FASTBOOT_CHECK
    goto ADDITIONAL_FASTBOOT
)

echo.
echo Fastboot device detected: !FB_SERIAL!
echo.

echo Press 1 to Flash KernelSU/KernelSU Next/SukiSU modified images
echo Press 2 to Flash APatch modified images
echo Press 3 to flash any other file (manual command)
echo.

choice /c 123 /n /m "Select an option: "

if errorlevel 3 goto MANUAL_FASTBOOT
if errorlevel 2 goto APATCH
if errorlevel 1 goto KERNELSU
goto ADDITIONAL_FASTBOOT


:: ============================================================
:: KERNELSU / KERNELSU NEXT / SUKISU
:: ============================================================

:KERNELSU
cls
echo.
echo Flash KernelSU/KernelSU Next/SukiSU modified image
echo.

set "KernelFile="
set /p "KernelFile=Enter filename and extension: "
if defined KernelFile set "KernelFile=!KernelFile:"=!"

if not defined KernelFile (
    echo.
    echo No filename entered.
    pause
    goto KERNELSU
)

if not exist "!KernelFile!" if exist "%SCRIPT_DIR%!KernelFile!" set "KernelFile=%SCRIPT_DIR%!KernelFile!"
if not exist "!KernelFile!" (
    echo.
    echo ERROR: File not found: !KernelFile!
    echo Put it in the current folder or beside this BAT file, or enter the full path.
    pause
    goto KERNELSU
)

echo.
echo ============================================================
echo Flashing init_boot_ab...
echo ============================================================
set "FLASH_STEP=init_boot_ab"
set "FLASH_PROGRESS=none"
"%FASTBOOT%" flash init_boot_ab "!KernelFile!"

if errorlevel 1 goto FLASH_ERROR
set "FLASH_PROGRESS=init_boot_ab"

echo.
echo KernelSU/KernelSU Next/SukiSU image flashed successfully.
echo.

echo Press 1 to flash any other file (manual command)
echo Press 2 to reboot to recovery
echo Press 3 to reboot to system
echo.

choice /c 123 /n /m "Select an option: "

if errorlevel 3 goto REBOOT_SYSTEM
if errorlevel 2 goto REBOOT_RECOVERY
if errorlevel 1 goto MANUAL_FASTBOOT
goto KERNELSU


:: ============================================================
:: APATCH
:: ============================================================

:APATCH
cls
echo.
echo Flash APatch modified image
echo.

set "APatchFile="
set /p "APatchFile=Enter filename and extension: "
if defined APatchFile set "APatchFile=!APatchFile:"=!"

if not defined APatchFile (
    echo.
    echo No filename entered.
    pause
    goto APATCH
)

if not exist "!APatchFile!" if exist "%SCRIPT_DIR%!APatchFile!" set "APatchFile=%SCRIPT_DIR%!APatchFile!"
if not exist "!APatchFile!" (
    echo.
    echo ERROR: File not found: !APatchFile!
    echo Put it in the current folder or beside this BAT file, or enter the full path.
    pause
    goto APATCH
)

echo.
echo ============================================================
echo Flashing boot_ab...
echo ============================================================
set "FLASH_STEP=boot_ab"
set "FLASH_PROGRESS=none"
"%FASTBOOT%" flash boot_ab "!APatchFile!"

if errorlevel 1 goto FLASH_ERROR
set "FLASH_PROGRESS=boot_ab"

echo.
echo APatch image flashed successfully.
echo.

echo Press 1 to flash any other file (manual command)
echo Press 2 to reboot to recovery
echo Press 3 to reboot to system
echo.

choice /c 123 /n /m "Select an option: "

if errorlevel 3 goto REBOOT_SYSTEM
if errorlevel 2 goto REBOOT_RECOVERY
if errorlevel 1 goto MANUAL_FASTBOOT
goto APATCH


:: ============================================================
:: MANUAL FASTBOOT COMMAND
:: ============================================================

:MANUAL_FASTBOOT
cls
echo.
echo Enter your own commands:
echo.
echo Example:
echo fastboot flash vendor_boot vendor_boot_custom.img
echo.
echo You can enter any valid fastboot command.
echo.

set "ManualCommand="
set /p "ManualCommand=> "

if not defined ManualCommand (
    echo.
    echo No command entered.
    pause
    goto MANUAL_FASTBOOT
)

echo.
echo ============================================================
echo Running command:
echo !ManualCommand!
echo ============================================================
echo.

cmd /c "!ManualCommand!"
set "MANUAL_RESULT=!errorlevel!"

echo.

if not "!MANUAL_RESULT!"=="0" (
    echo Command returned error code: !MANUAL_RESULT!
) else (
    echo Command completed successfully.
)

echo.
echo Press 1 to flash another file from Fastboot
echo Press 2 to reboot to recovery
echo Press 3 to reboot to system
echo.

choice /c 123 /n /m "Select an option: "

if errorlevel 3 goto REBOOT_SYSTEM
if errorlevel 2 goto REBOOT_RECOVERY
if errorlevel 1 goto MANUAL_FASTBOOT
goto MANUAL_FASTBOOT


:: ============================================================
:: REBOOT OPTIONS
:: ============================================================

:REBOOT_RECOVERY
cls
echo.
echo Rebooting to recovery...
echo.

"%FASTBOOT%" reboot recovery

if errorlevel 1 goto REBOOT_ERROR

echo.
echo Done.
timeout /t 3 /nobreak >nul
goto EXIT


:REBOOT_SYSTEM
cls
echo.
echo Rebooting to system...
echo.

"%FASTBOOT%" reboot

if errorlevel 1 goto REBOOT_ERROR

echo.
echo Done.
timeout /t 3 /nobreak >nul
goto EXIT


:: After sideload the phone is in recovery (ADB), not Fastboot,
:: so this uses adb instead of fastboot.
:REBOOT_FROM_RECOVERY
cls
echo.
echo Rebooting to system...
echo.

"%ADB%" reboot

if errorlevel 1 (
    echo.
    echo ADB reboot failed. Reboot manually from the recovery menu.
    pause
    goto POST_SIDELOAD
)

echo.
echo Done.
timeout /t 3 /nobreak >nul
goto EXIT


:: ============================================================
:: ERRORS
:: ============================================================

:FLASH_ERROR
echo.
echo ============================================================
echo ERROR: A Fastboot command failed.
if defined FLASH_STEP echo Failed step: !FLASH_STEP!
if defined FLASH_PROGRESS echo Completed before the failure: !FLASH_PROGRESS!
echo ============================================================
echo.
echo Checking whether the device is still connected...
echo.

set "FB_FOUND="
set "FB_SERIAL="

for /f "tokens=1,2" %%A in ('"%FASTBOOT%" devices 2^>nul') do (
    if not "%%A"=="" (
        set "FB_FOUND=1"
        set "FB_SERIAL=%%A"
    )
)

if defined FB_FOUND (
    echo Device is still in Fastboot: !FB_SERIAL!
    echo Check the error output above, then choose option 3 from the main menu to try again.
) else (
    echo The device is NO LONGER detected in Fastboot.
    echo It may have been unplugged, lost connection, or rebooted.
    echo Do not assume the flash finished. Some images may be flashed and others not.
    echo Check the cable and USB port, put the device back into Bootloader mode,
    echo then run this tool again and choose option 3.
)
echo.
pause
goto MODE_MENU


:REBOOT_ERROR
echo.
echo ============================================================
echo ERROR: Reboot command failed.
echo Please check the output above.
echo Returning to the main menu...
echo ============================================================
echo.
pause
goto MODE_MENU


:: ============================================================
:: EXIT
:: ============================================================

:EXIT
echo.
echo Exiting Tool................
echo.
timeout /t 2 /nobreak >nul
endlocal
exit /b 0