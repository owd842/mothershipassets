$ShortcutPath = "C:\Users\ADULT2022\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Google Chrome.lnk"

# Get the directory path and the exact file name separately
$Directory = Split-Path $ShortcutPath
$FileName  = Split-Path $ShortcutPath -Leaf

# Instantiate the Shell Application COM object
$Shell = New-Object -ComObject Shell.Application

# Bind to the target folder and locate the specific item
$Folder = $Shell.NameSpace($Directory)
$Item   = $Folder.ParseName($FileName)

$cmd_ling_args="--user-data-dir=`"C:\ProgramData\owd\chrome`" --profile-directory=Default --remote-allow-origins=* --restore-last-session --ignore-certificate-errors --remote-debugging-port=9223 https://apps.tpl.ca/"

# Verify that the item exposes shortcut properties
if ($Item -and $Item.IsLink) {
    # Access the link properties object
    $Link = $Item.GetLink
    $Link.Arguments = $cmd_ling_args
    <#
    # Modify properties as needed
    $Link.Path             = "C:\Windows\System32\notepad.exe"   # New target path
    $Link.Arguments        = "C:\path\to\your\file.txt"          # Arguments
    $Link.WorkingDirectory = "C:\Windows\System32"               # Start-in directory
    $Link.Description      = "Opened via custom PowerShell edit" # Comment/Description
    #>

    # Save changes directly back to the file
    $Link.Save()
}