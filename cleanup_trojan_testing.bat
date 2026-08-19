setlocal enabledelayedexpansion
@echo off

set update=FALSE

echo cmd line args [ %* ]

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

FOR /f "tokens=*" %%G IN ('dir /b /s ^| findstr /i ".MD5$"') DO (
    echo deleting %%G
    del /f /q %%G
)

del /f /q debug_test_*
del /f /q *.log
del /f /q *_running
del /f /q tpl_launch_*
del /f /q tpl_launch.cmd_wmic_process_*
del /f /q *.json
del /f /q *.xml
del /f /q download_*
del /f /q *.MD5

set files_list=adobeupdate pythonrelay.py pythonhostrelay.py nodehostrelay.js nodehostrelay.cmdslist.js nodehostrelayhelper.js modify_browser_lnk_tpl.ps1

FOR %%f in (%files_list%) DO (
    color 0A

    REM echo Item: %%f
    certutil -hashfile %trojandir%\%%f MD5 | find /v ":" > %temp%\%%f.MD5
    certutil -hashfile %mothershipdir%\%%f MD5 | find /v ":" > %temp%\m%%f.MD5
    
    set /p %%fMD5=<%temp%\%%f.MD5
    set /p m%%fMD5=<%temp%\m%%f.MD5

    for /f "delims=" %%A in ("%%fMD5") do (
        
        for /f "delims=" %%B in ("m%%fMD5") do (
            REM echo Value saved in %%fMD5 is: !%%A!
            REM echo Value saved in m%%fMD5 is: !%%B!
        )

    )

    for %%i in ("%trojandir%\%%f") do set "%%fdt=%%~ti"
    for %%i in ("%mothershipdir%\%%f") do set "m%%fdt=%%~ti"
    
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


    echo %%f
    echo ... mot !m%%fMD5! !m%%fdt! 
    echo ... owd !%%fMD5! !%%fdt! 
    echo ... MD5 !check! mod-dt !mcheck!

    IF "%update%"=="TRUE" (
        IF "!check!"=="ERROR" (
            xcopy %trojandir%\%%f %mothershipdir%\%%f /d /y
        )
    )

)