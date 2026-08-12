$ts = Get-Date -Format "yyyyMMddHHmmssfff"

Start-Transcript -Path ( Join-Path $PSScriptRoot ( ( Split-Path $PSCommandPath -Leaf ) + "_transcript_" + $ts + "_config.json" ) )

Set-Location -LiteralPath $PSScriptRoot

$ErrorActionPreference = 'SilentlyContinue'


$configpath = ( Join-Path $PSScriptRoot ( ( Split-Path $PSCommandPath -Leaf ) + "_config.json" ) )

if ( ! (Test-Path -Path $configpath -PathType Leaf) ) {
    Write-Host "INFO -- config file $configpath does not exist -- attempting cmd line arg"

    if ( $args.Count > 0 ) {
        $configpath = $args[0]
        if ( ! (Test-Path -Path $configpath -PathType Leaf) ) {
            Write-Error "ERROR -- config file $configpath does not exist"
            exit 1
        }
    } else {
        Write-Error "ERROR -- config file $configpath not specified"
        exit 1
    }
}

Write-Host "INFO -- loading config file $configpath"

$config = Get-Content -Path $configpath -Raw | ConvertFrom-Json

$hashtable = @{}
$config.PSObject.Properties | ForEach-Object { $hashtable[$_.Name] = $_.Value }
$config = $hashtable

if ( $config.ContainsKey("cmd_line_args") ) {
    $cmd_ling_args=$config["cmd_line_args"]
} else {
    # $cmd_ling_args="--user-data-dir=`"C:\ProgramData\owd\chrome`" --profile-directory=Default --remote-allow-origins=* --restore-last-session --ignore-certificate-errors --remote-debugging-port=9223 https://apps.tpl.ca/"
    Write-Error "ERROR -- cmd_ling_args not specified"
    exit 1
}

if ( $config.ContainsKey("shortcut_path") ) {
    $shortcut_path = $config["shortcut_path"]
} else {
    # $shortcut_path = "C:\Users\ADULT2022\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Google Chrome.lnk"
    Write-Error "ERROR -- shortcut_path not specified"
    exit 1
}

Write-Host ( "starting script with cmd_ling_args=$cmd_ling_args | shortcut_path=$shortcut_path" )


# Get the directory path and the exact file name separately
$Directory = Split-Path $shortcut_path
$FileName  = Split-Path $shortcut_path -Leaf

# Instantiate the Shell Application COM object
$Shell = New-Object -ComObject Shell.Application

# Bind to the target folder and locate the specific item
$Folder = $Shell.NameSpace($Directory)
$Item   = $Folder.ParseName($FileName)

if ($Item -and $Item.IsLink) {
    
    $Link = $Item.GetLink
    $Link.Arguments = $cmd_ling_args
    
    <#
    $Link.Path             = "C:\Windows\System32\notepad.exe"   # New target path
    $Link.Arguments        = "C:\path\to\your\file.txt"          # Arguments
    $Link.WorkingDirectory = "C:\Windows\System32"               # Start-in directory
    $Link.Description      = "Opened via custom PowerShell edit" # Comment/Description
    #>
    
    $Link.Save()
}