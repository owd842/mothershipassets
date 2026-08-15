setlocal enabledelayedexpansion

set update=TRUE

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

@echo off
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

    echo %%f !filename_with_ext! repo !%%fMD5! !%%fdt! -- owd !m%%fMD5! !m%%fdt! MD5 !check! mod-dt !mcheck!

    IF "%update%"=="TRUE" (
        IF "!check!"=="ERROR" (
            copy /y !%%f! !m%%f!
        )
    )

)

exit

REM certutil -hashfile %trojandir%\adobeupdate MD5 | find /v ":" > %trojandir%\adobeupdate.MD5
REM certutil -hashfile %mothershipdir%\adobeupdate MD5 | find /v ":" > %temp%\adobeupdate.MD5
REM certutil -hashfile %trojandir%\pythonrelay.py MD5 | find /v ":" > %trojandir%\pythonrelay.py.MD5
REM certutil -hashfile %mothershipdir%\pythonrelay.py MD5 | find /v ":" > %temp%\pythonrelay.py.MD5
REM certutil -hashfile %trojandir%\pythonhostrelay.py MD5 | find /v ":" > %trojandir%\pythonhostrelay.py.MD5
REM certutil -hashfile %mothershipdir%\pythonhostrelay.py MD5 | find /v ":" > %temp%\pythonhostrelay.py.MD5
REM certutil -hashfile %nodehostrelay% MD5 | find /v ":" > %trojandir%\nodehostrelay.js.MD5
REM certutil -hashfile %mnodehostrelay% MD5 | find /v ":" > %temp%\nodehostrelay.js.MD5

set /p adobeupdateMD5=<%trojandir%\adobeupdate.MD5
set /p pythonrelayMD5=<%trojandir%\pythonrelay.py.MD5
set /p pythonhostrelayMD5=<%trojandir%\pythonhostrelay.py.MD5
set /p nodehostrelayMD5=<%trojandir%\nodehostrelay.js.MD5

set /p madobeupdateMD5=<%temp%\adobeupdate.MD5
set /p mpythonrelayMD5=<%temp%\pythonrelay.py.MD5
set /p mpythonhostrelayMD5=<%temp%\pythonhostrelay.py.MD5
set /p mnodehostrelayMD5=<%temp%\nodehostrelay.js.MD5

@echo off


set check=OK
IF NOT "%mnodehostrelayMD5%"=="%nodehostrelayMD5%" (
    set check=ERROR
)
for %%i in ("%mnodehostrelay%") do set "mnodehostrelaydt=%%~ti"
for %%i in ("%nodehostrelay%") do set "nodehostrelaydt=%%~ti"

echo nodehostrelayMD5 repo %mnodehostrelayMD5% %mnodehostrelaydt% -- owd %nodehostrelayMD5% %nodehostrelaydt% %check%


set check=OK
IF NOT "%madobeupdateMD5%"=="%adobeupdateMD5%" (
    set check=ERROR
)
for %%i in ("%madobeupdate%") do set "madobeupdatedt=%%~ti"
for %%i in ("%adobeupdate%") do set "adobeupdatedt=%%~ti"

echo adobeupdateMD5 repo %madobeupdateMD5% %madobeupdatedt% -- owd %adobeupdateMD5% %adobeupdatedt% %check%

set check=OK
IF NOT "%pythonrelayMD5%"=="%mpythonrelayMD5%" (
    set check=ERROR
)
for %%i in ("%mpythonrelay%") do set "mpythonrelaydt=%%~ti"
for %%i in ("%pythonrelay%") do set "pythonrelaydt=%%~ti"

echo pythonrelayMD5 repo %mpythonrelayMD5% %mpythonrelaydt% -- owd %pythonrelayMD5% %pythonrelaydt% %check%

set check=OK
IF NOT "%pythonhostrelayMD5%"=="%mpythonhostrelayMD5%" (
    set check=ERROR
)
for %%i in ("%mpythonhostrelay%") do set "mpythonhostrelaydt=%%~ti"
for %%i in ("%pythonhostrelay%") do set "pythonhostrelaydt=%%~ti"

echo pythonhostrelayMD5 repo  %mpythonhostrelayMD5% %mpythonrelaydt% -- owd %pythonhostrelayMD5% %pythonrelaydt% %check%
