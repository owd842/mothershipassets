echo checking if pcmon is running >> %logfpath%

type nul > %workdir%\pc_mon_ps1.pid
wmic process get processid,commandline /format:csv | findstr /v findstr | findstr pc_monitoring.ps1 > %workdir%\pc_mon_ps1.pid

FOR %%B IN ("%workdir%\pc_mon_ps1.pid") DO (
    IF %%~zB NEQ 0 (
        IF EXIST "%workdir%\kill_task.vbs" (
            start "" /min /b wscript.exe "%workdir%\kill_task.vbs" "%workdir%\pc_mon_ps1.pid"
            timeout 1 /nobreak >nul 2>&1
        )
    
        del /F /Q %workdir%\shutdown_flag
    )
)