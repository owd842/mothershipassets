
# setup script for pscdp on client machines

# ! modify shortcuts (lnk) to point to correct binary with cmd line args enabling CDP
# ! needs windows task to pre-launch msedge, chrome + headless msedge for pubnubws
# C:\Users\LC2022\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar
# replace chrome with uchrome
# alternative for msedge: use vilvadi

# one time setup:
# make sure uchrome binaries are copied into C:\ProgramData\owd folder
# need to modify lnk files for msedge and chrome
# chrome --> change binary path to point to uchrome and cmd line args
# msedge --> change cmd line args only
# ! tpl --> msedge needs to be pinned to taskbar

# on machine startup we need:
# headless msedge running pointing to pubnub url
# punub url: https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub
# pscdp.relay.ps1 script running in powershell headless
# scheduled task seems to be the safer approach
# two tasks: one for msedge launch, another for ps1 script launch

# ungoogled chromium
# start chrome.exe --remote-debugging-port=9223 --profile-directory=Default --remote-allow-origins=* --suppress-message-center-popups  --noerrdialogs --disable-infobars --disable-notifications --no-first-run --no-default-browser-check --disable-signin-promo --hide-crash-restore-bubble --new-window https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub --remote-debugging-address=0.0.0.0 --remote-allow-origins=*
# https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub
# --headless=new
# --auto-open-devtools-for-tabs
# --remote-debugging-address=0.0.0.0
# --remote-allow-origins=* 
# --force-devtools-available
# --disable-features=StartupLaunch
# frontend.appspot.com
# msedge requires --user-data-dir="%TEMP%\edge-debug-profile" # on tpl, not required (some pcs, not all)
