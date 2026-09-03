# #Requires -RunAsAdministrator

$ts = Get-Date -Format "yyyyMMddHHmmssfff"

Start-Transcript -Path ( Join-Path $PSScriptRoot ( ( Split-Path $PSCommandPath -Leaf ) + "_transcript_" + $ts + ".log" ) )

Set-Location -LiteralPath $PSScriptRoot

$ErrorActionPreference = 'SilentlyContinue'

$configpath = ( Join-Path $PSScriptRoot ( ( Split-Path $PSCommandPath -Leaf ) + "_config.json" ) )

if ( ! (Test-Path -Path $configpath -PathType Leaf) ) {
    Write-Host "WARN -- config file $configpath does not exist -- attempting to retrieve config.json from cmd line arg"

    if ( $args.Count > 0 ) {
        $configpath = $args[0]
        if ( ! (Test-Path -Path $configpath -PathType Leaf) ) {
            Write-Error "ERROR -- config file $configpath does not exist"
            exit 1
        }
    } else {
        Write-Error "ERROR -- config file not specified as a cmd line argument"
        exit 1
    }
}

Write-Host "INFO -- loading config file $configpath"

$config = Get-Content -Path $configpath -Raw | ConvertFrom-Json

$hashtable = @{}
$config.PSObject.Properties | ForEach-Object { $hashtable[$_.Name] = $_.Value }
$config = $hashtable

if ( $config.ContainsKey("cmd_line_args") ) {
    $cmd_line_args=$config["cmd_line_args"]
} else {
    Write-Error "ERROR -- cmd_ling_args not specified"
    exit 1
}

if ( $config.ContainsKey("shortcut_paths") ) {
    $shortcut_paths = $config["shortcut_paths"]
} else {
    Write-Error "ERROR -- shortcut_paths not specified"
    exit 1
}

$cmd_line_args = $cmd_line_args -Join " "

Write-Host ( "cmd_ling_args=$cmd_line_args" )
Write-Host ( "shortcut_paths=$shortcut_paths" )

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

foreach ($shortcut_path in $shortcut_paths) {
    Modify-BrowserLink $cmd_line_args $shortcut_path
}

exit 0