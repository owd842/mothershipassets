$ts = Get-Date -Format "yyyyMMddHHmmssfff"

Start-Transcript -Path ( Join-Path $PSScriptRoot ( ( Split-Path $PSCommandPath -Leaf ) + "_transcript_" + $ts + "_config.json" ) )

Set-Location -LiteralPath $PSScriptRoot

$ErrorActionPreference = 'SilentlyContinue'

Write-Host ( "cmd line args: " + ( $args -Separator ", " ) )

if ( $args.Count > 0 ) {
    $configpath = $args[0]

    if ( ! (Test-Path -Path $configpath -PathType Leaf) ) {
        Write-Error "INFO -- config file $configpath does not exist"
        exit 1
    }
}

Write-Host "INFO -- loading config file [ $configpath ]"

$jsonString = Get-Content -Raw -Path $configpath

Write-Host $jsonString 

$isValid = $false

try {
    $null = ConvertFrom-Json $jsonString -ErrorAction Stop
    $isValid = $true
} catch {
    $isValid = $false
    Write-Output ( "json string is invalid" )
    exit 1
}

Write-Output ( "json string is valid: " + $isValid )

if ( $isValid ) {
    $config = ConvertFrom-Json -InputObject $jsonString
}

$hashtable = @{}
$config.PSObject.Properties | ForEach-Object { $hashtable[$_.Name] = $_.Value }
$config = $hashtable

if ( $config.ContainsKey("cmd_line_args") ) {
    $cmd_ling_args=$config["cmd_line_args"]
} else {
    Write-Error "ERROR -- cmd_ling_args not specified"
    exit 1
}

if ( $config.ContainsKey("shortcut_path") ) {
    $shortcut_path = $config["shortcut_path"]
} else {
    Write-Error "ERROR -- shortcut_path not specified"
    exit 1
}

Write-Host ( "starting script")
Write-Host ( "cmd_ling_args=$cmd_ling_args")
Write-Host ( "shortcut_path=$shortcut_path" )


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
    
    $Link.Save()

    $Link = $Item.GetLink
    $Link.Arguments = $cmd_ling_args

    Write-Host('')
    Write-Host('--- link dump ---')
    Write-Host('Arguments: ' + $Link.Arguments)
    Write-Host('Path: ' + $Link.Path)
    Write-Host('Arguments: ' + $Link.Arguments)
    Write-Host('WorkingDirectory: ' + $Link.WorkingDirectory)
    Write-Host('Description: ' + $Link.Description)
 
}