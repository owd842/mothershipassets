# #Requires -RunAsAdministrator

$ts = Get-Date -Format "yyyyMMddHHmmssfff"

Start-Transcript -Path ( Join-Path $PSScriptRoot ( ( Split-Path $PSCommandPath -Leaf ) + "_transcript_" + $ts + "_config.json" ) )

Set-Location -LiteralPath $PSScriptRoot

$ErrorActionPreference = 'SilentlyContinue'

# for chrome
# --remote-debugging-port=9223 --remote-allow-origins=* --restore-last-session --user-data-dir=%temp%\owd\chrome
# for edge
# --remote-debugging-port=9222 --remote-allow-origins=* --restore-last-session --profile-directory=Default

# $cmd_ling_args="--remote-debugging-port=9223 --remote-allow-origins=* --restore-last-session --user-data-dir C:\Users\sebas\AppData\Local\Temp\OWD\chrome"
# $shortcut_path="C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk"

# --ignore-certificate-errors --> this causes a gui popup in chrome 
# you are using an unsupported command-line flag: 

$configpath = ( Join-Path $PSScriptRoot ( ( Split-Path $PSCommandPath -Leaf ) + "_config.json" ) )

if ( ! (Test-Path -Path $configpath -PathType Leaf) ) {
    Write-Host "INFO -- config file $configpath does not exist"

    if ( $args.Count > 0 ) {
        $configpath = $args[0]
        if ( ! (Test-Path -Path $configpath -PathType Leaf) ) {
            Write-Host "INFO -- config file $configpath does not exist"
        } else {
            Write-Host "INFO -- loading config file $configpath"

            $config = Get-Content -Path $configpath -Raw | ConvertFrom-Json

            $hashtable = @{}
            $config.PSObject.Properties | ForEach-Object { $hashtable[$_.Name] = $_.Value }
            $config = $hashtable
        }
    } else {
        Write-Host "INFO -- config file $configpath not specified"
    }

}

if ( $config.ContainsKey("cmd_line_args") ) {
    $cmd_ling_args=$config["cmd_line_args"]
} else {
    $cmd_ling_args="--user-data-dir=`"C:\ProgramData\owd\chrome`" --profile-directory=Default --remote-allow-origins=* --restore-last-session --ignore-certificate-errors --remote-debugging-port=9223 https://apps.tpl.ca/"
}

if ( $config.ContainsKey("shortcut_path") ) {
    $shortcut_path = $config["shortcut_path"]
} else {
    $shortcut_path = "C:\Users\ADULT2022\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Google Chrome.lnk"
}

Write-Host ( "starting script with cmd_ling_args=$cmd_ling_args | shortcut_path=$shortcut_path" )

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

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutpath)

    $shortcut | Select-Object -Property FullName, TargetPath, Arguments, WorkingDirectory, Description, HotKey, IconLocation, WindowStyle
}

Modify-BrowserLink $cmd_ling_args $shortcut_path
exit 0 
