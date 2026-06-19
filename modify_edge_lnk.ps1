# #Requires -RunAsAdministrator

$ts = Get-Date -Format "yyyyMMddHHmmssfff"

Start-Transcript -Path ("modify_edge_lnk.ps1_ps1_transcript_" + $ts + ".log")

Set-Location -LiteralPath $PSScriptRoot

$ErrorActionPreference = 'SilentlyContinue'

# for chrome
# --remote-debugging-port=9223 --remote-allow-origins=* --restore-last-session --user-data-dir=%temp%\owd\chrome
# for edge
# --remote-debugging-port=9222 --remote-allow-origins=* --restore-last-session --profile-directory=Default

# $cmd_ling_args="--remote-debugging-port=9223 --remote-allow-origins=* --restore-last-session --user-data-dir C:\Users\sebas\AppData\Local\Temp\OWD\chrome"
# $shortcut_path="C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk"

$cmd_ling_args=""
$shortcut_path=""

if ( $args.Count -gt 1 ) {
    $cmd_ling_args=$args[0]
    $shortcut_path=$args[1]
} else {
    Write-Host "ERROR -- must specify cmd ling arg, and shortcut path"
    exit 1
}


$user_data_dir=""
if ( $args.Count -gt 2 ) {
    $user_data_dir=$args[2]
}
    
Write-Host ( "starting script with cmd_ling_args=" + $cmd_ling_args + " | shortcut_path=" + $shortcut_path )

function Modify-BrowserLink {
    param (
        [string]$cmdlineargs,
        [string]$shortcutpath
    )

    Write-Host "Modify-BrowserLink: " + ($args -join " ")
    
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutpath)

    $shortcut.Arguments = "$cmdlineargs"
    $shortcut.Save()

    $wshell = New-Object -ComObject WScript.Shell
    $shortcut = $wshell.CreateShortcut($shortcutpath)
    $shortcut | Select-Object -Property FullName, TargetPath, Arguments, WorkingDirectory, Description, HotKey, IconLocation, WindowStyle
}

Modify-BrowserLink $cmd_ling_args $shortcut_path
exit 0 