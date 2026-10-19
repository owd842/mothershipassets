# & $path --remote-debugging-port=9222 --profile-directory=Default --remote-allow-origins=* --suppress-message-center-popups  --noerrdialogs --disable-infobars --disable-notifications --no-first-run --no-default-browser-check --disable-signin-promo --hide-crash-restore-bubble --new-window https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub --remote-debugging-address=0.0.0.0 --remote-allow-origins=* --user-data-dir=$datadir
# & $( Join-Path $path "chrome.exe" ) --remote-debugging-port=9223 --profile-directory=Default --remote-allow-origins=* --suppress-message-center-popups  --noerrdialogs --disable-infobars --disable-notifications --no-first-run --no-default-browser-check --disable-signin-promo --hide-crash-restore-bubble --new-window https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub --remote-debugging-address=0.0.0.0 --remote-allow-origins=* --user-data-dir=$datadir
# taskkill /F /IM chrome.exe
#taskkill /F /IM msedge.exe
# C:\Program Files (x86)\Google\Chrome\Application\chrome.exe
# C:\Users\LC2022\AppData\Local\uchrome\ungoogled-chromium_154.0.8037.97-1.1_windows_x64
#$path = "C:\MAIN\__Binaries\ungoogled-chromium_154.0.8037.97-1.1_windows_x64\ungoogled-chromium_154.0.8037.97-1.1_windows_x64"

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

& subst Z: C:\

$launch_chrome = {

    $ungoogled_paths = @(
        "ungoogled-chromium_152.0.7977.82-1.1_windows_x64",
        "ungoogled-chromium_155.0.8059.79-1.1_windows_x64",
        "ungoogled-chromium_155.0.8059.39-1.1_windows_x64"
    )

    if ( $env:COMPUTERNAME -eq "LAPTOP-638Q0G5V" ) {
        $rootpath = "C:\Binaries" 
    } else {
        $rootpath = "Z:\Users\$($env:USERNAME)\AppData\Local\WORKING\binaries"
    }

    $foundpath = $true
    $path = ""

    for ($i=0; $i -lt $ungoogled_paths.Count; $i++ ) {
        $paths = @( $rootpath,  $ungoogled_paths[$i], $ungoogled_paths[$i], "chrome.exe" )

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

    $sargs = @{
        "remote-debugging-port"="9223";
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
        #"new-window"="https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub";
        "remote-debugging-address"="0.0.0.0";
        "user-data-dir"=$datadir  
    }

    $targs = ConvertArgs $sargs

    & $path $targs

    $resp = (Invoke-WebRequest -Uri http://localhost:9223/json -UseBasicParsing).Content | ConvertFrom-Json

    if ( $null -ne $resp -and $resp.Length -ge 1 ) {
        Write-Host "9223 is ok"
    } else {
        throw "9223 not responsive"   
    }

}

$launch_msedge = {

    if ( $env:COMPUTERNAME -eq "BWPCP506" ) {
        $path = "C:\Users\$($env:USERNAME)\AppData\Local\vivaldi\Vivaldi-bin\vivaldi.exe"
    } else {
        $path = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    }

    if ( ! ( Test-Path -Path $path -PathType Leaf ) ) {
        throw "$path does not exist"
    }

    $datadir = "C:\Users\$($env:USERNAME)\AppData\Local\msedge-test"

    $sargs = @{
        "remote-debugging-port"="9222";
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

    & $path $targs

    $resp = (Invoke-WebRequest -Uri http://localhost:9222/json -UseBasicParsing).Content | ConvertFrom-Json

    if ( $null -ne $resp -and $resp.Length -ge 1 ) {
        Write-Host "9222 is ok"
    } else {
        throw "9222 not responsive"   
    }
}

if ( ! $env:COMPUTERNAME -eq "BWPCP506" ) {
    & $launch_chrome
}

& $launch_msedge