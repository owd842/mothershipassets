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


FOR /F "tokens=1,2" %%A IN ('wmic logicaldisk get name^,volumename 2^>nuls ^| findstr /I /C:"MAIN"') DO SET "DRIVE_LETTER=%%A"

set mothershipdir=%DRIVE_LETTER%\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets
cd /d %mothershipdir%

FOR /f "tokens=*" %%G IN ('dir /b ^| findstr /i ".MD5$"') DO (
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