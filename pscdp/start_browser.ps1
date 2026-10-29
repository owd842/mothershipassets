# & $path --remote-debugging-port=9222 --profile-directory=Default --remote-allow-origins=* --suppress-message-center-popups  --noerrdialogs --disable-infobars --disable-notifications --no-first-run --no-default-browser-check --disable-signin-promo --hide-crash-restore-bubble --new-window https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub --remote-debugging-address=0.0.0.0 --remote-allow-origins=* --user-data-dir=$datadir
# & $( Join-Path $path "chrome.exe" ) --remote-debugging-port=9223 --profile-directory=Default --remote-allow-origins=* --suppress-message-center-popups  --noerrdialogs --disable-infobars --disable-notifications --no-first-run --no-default-browser-check --disable-signin-promo --hide-crash-restore-bubble --new-window https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub --remote-debugging-address=0.0.0.0 --remote-allow-origins=* --user-data-dir=$datadir
# taskkill /F /IM chrome.exe
#taskkill /F /IM msedge.exe
# C:\Program Files (x86)\Google\Chrome\Application\chrome.exe
# C:\Users\LC2022\AppData\Local\uchrome\ungoogled-chromium_154.0.8037.97-1.1_windows_x64
#$path = "C:\MAIN\__Binaries\ungoogled-chromium_154.0.8037.97-1.1_windows_x64\ungoogled-chromium_154.0.8037.97-1.1_windows_x64"

$processes = Get-CimInstance Win32_Process | Select-Object Name, ProcessId, CommandLine, ExecutablePath

function PingDebugPort {
    param([string]$debugport)

    $resp = (Invoke-WebRequest -Uri http://localhost:$($debugport)/json -UseBasicParsing).Content | ConvertFrom-Json

    if ( $null -ne $resp -and $resp.Length -ge 1 ) {
        Write-Host "$debugport is ok"
        return $true
    }

    Write-Error "$debugport not responsive"

    return $false
}

function IsBrowserRunning {
    param([string]$procname, [string]$debugport, [string]$exepath)

    $str = "*remote-debugging-port=" + $debugport + "*"

    if ( [string]::IsNullOrWhiteSpace($exepath) ) {
        $processes = Get-CimInstance Win32_Process | Select-Object Name, ProcessId, CommandLine
        $processes = $processes | Where-Object { $_.Name -eq $procname -and  $_.CommandLine -like $str }
    } else {
        $processes = Get-CimInstance Win32_Process | Select-Object Name, ProcessId, CommandLine, ExecutablePath
        $processes = $processes | Where-Object { $_.Name -eq $procname -and  $_.CommandLine -like $str -and $_.ExecutablePath -like $exepath }
    }

    if ( $processes.Count -ge 1 ) {
        return $true
    }

    return $false
}

function ConvertArgs {
    param([hashtable]$sargs)

    $targs = @()
    $sargs.GetEnumerator() | ForEach-Object {
        
        if ( $null -eq $_.Value ) {
            $targs += "--$($_.Key)"
        } else {

            if ( $_.Key -eq "new-window" ) {
                $targs += "--$($_.Key)"
                $targs += $_.Value
            } else {
                $targs += "--$($_.Key)=$($_.Value)"
            }

        }

    }

    return $targs
}

function LaunchBrowser {
    param([int32]$debugport = 9222, [string]$exepath, [string]$datadir)

    if ( ! ( Test-Path -Path $exepath -PathType Leaf ) ) {
        throw "$exepath does not exist"
    }

    $sargs = @{
        "remote-debugging-port"="$debugport";
        "profile-directory"="Default";
        "remote-allow-origins"="*";
        "suppress-message-center-popups"=$null;
        "noerrdialogs"=$null;
        "disable-infobars"=$null;
        "disable-notifications"=$null;
        "no-first-run"=$null;
        "no-default-browser-check"=$null;
        "disable-signin-promo"=$null;
        "hide-crash-restore-bubble"=$null;
        "new-window"="https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub";
        "remote-debugging-address"="0.0.0.0";
        "user-data-dir"=$datadir
    }

    $targs = ConvertArgs $sargs

    $process = Start-Process -FilePath $path -ArgumentList "$( $targs -join " " )" -PassThru

    if ( ! $process.HasExited ) {
        Write-Host "The process is currently RUNNING (PID: ($($process.Id))."
    } else {
        Write-Error "process failed to launch [$exepath]"
    }

}


$launch_chrome = {
    param([string]$debugport = "9223", [string]$chromepath)

    $ungoogled_paths = @(
        "ungoogled-chromium_152.0.7977.82-1.1_windows_x64",
        "ungoogled-chromium_155.0.8059.79-1.1_windows_x64",
        "ungoogled-chromium_155.0.8059.39-1.1_windows_x64"
    )

    if ( $env:COMPUTERNAME -eq "LAPTOP-638Q0G5V" ) {
        $rootpath = "C:\Binaries"
    } else {
        $rootpath = "Z:\Users\$($env:USERNAME)\AppData\Local\uchrome"
    }

    $foundpath = $true
    $path = ""

    for ($i=0; $i -lt $ungoogled_paths.Count; $i++ ) {
        $paths = @( $rootpath,  $ungoogled_paths[$i], "chrome.exe" )

        $path = $paths -join "\"

        if ( ! ( Test-Path -Path $path -PathType Leaf ) ) {
            $foundpath = $false
            continue
        } else {
            $foundpath = $true
            break
        }

    }

    if ( ! $foundpath ) {
            throw "$path does not exist"
    }

    $datadir = "C:\Users\$($env:USERNAME)\AppData\Local\chrome-test"

    LaunchBrowser $debugport $path $datadir
}

$launch_msedge = {
    param([string]$debugport = "9222")

    $path = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

    if ( [string]::IsNullOrWhiteSpace($datadir) ) {
        $datadir = "C:\Users\$($env:USERNAME)\AppData\Local\msedge-test"
    }

    LaunchBrowser $debugport $path $datadir
}

$launch_vivaldi = {
    param([string]$debugport = "9222")

    $path = "C:\Users\$($env:USERNAME)\AppData\Local\vivaldi\Vivaldi-bin\vivaldi.exe"

    if ( [string]::IsNullOrWhiteSpace($datadir) ) {
        $datadir = "C:\Users\$($env:USERNAME)\AppData\Local\msedge-test"
    }

    LaunchBrowser $debugport $path $datadir
}

& subst Z: C:\

$msedge_port ="9222"
$chrome_port = "9223"


if ( $env:COMPUTERNAME -eq "BWPCP506" ) {
    & $launch_vivaldi $msedge_port
} else {

    if ( ! ( IsBrowserRunning "chrome.exe" $chrome_port "*ungoogled*" ) ) {
        & $launch_chrome $chrome_port
    }

}

if ( ! ( IsBrowserRunning "msedge.exe" $msedge_port ) ) {
    & $launch_msedge $msedge_port
}
