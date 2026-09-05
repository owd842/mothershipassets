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

module.exports = {
    process_argv,
    invoke_exe,
    writeToChildProcess
};