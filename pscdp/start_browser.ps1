# taskkill /F /IM chrome.exe
#taskkill /F /IM msedge.exe
# C:\Program Files (x86)\Google\Chrome\Application\chrome.exe
# C:\Users\LC2022\AppData\Local\uchrome\ungoogled-chromium_154.0.8037.97-1.1_windows_x64
$path = "C:\MAIN\__Binaries\ungoogled-chromium_154.0.8037.97-1.1_windows_x64\ungoogled-chromium_154.0.8037.97-1.1_windows_x64"
#$path = "Z:\Users\LC2022\AppData\Local\WORKING\binaries\ungoogled-chromium_155.0.8059.39-1.1_windows_x64\ungoogled-chromium_155.0.8059.39-1.1_windows_x64"
& $( Join-Path $path "chrome.exe" ) --remote-debugging-port=9223 --profile-directory=Default --remote-allow-origins=* --suppress-message-center-popups  --noerrdialogs --disable-infobars --disable-notifications --no-first-run --no-default-browser-check --disable-signin-promo --hide-crash-restore-bubble --new-window https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub --remote-debugging-address=0.0.0.0 --remote-allow-origins=* --user-data-dir="C:\Users\LC2022\AppData\Local\chrome-test"
#& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --remote-debugging-port=9222 --profile-directory=Default --remote-allow-origins=* --suppress-message-center-popups  --noerrdialogs --disable-infobars --disable-notifications --no-first-run --no-default-browser-check --disable-signin-promo --hide-crash-restore-bubble --new-window https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub --remote-debugging-address=0.0.0.0 --remote-allow-origins=* --user-data-dir="C:\Users\LC2022\AppData\Local\msedge-test"
$respa = (Invoke-WebRequest -Uri http://localhost:9223/json -UseBasicParsing).Content
#$respb = (Invoke-WebRequest -Uri http://localhost:9222/json -UseBasicParsing).Content
$respa | Write-Host
#$respb | Write-Host