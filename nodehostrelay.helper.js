const path = require("path");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");
const util = require("util");

let modulename = path.basename(module.id);

var scriptdirpath = path.dirname(process.argv[1]);
var scriptfname = path.basename(process.argv[1]);
var logfpath = path.join(
    scriptdirpath,
    scriptfname + "_" + getTimestamp() + ".log"
);

let uinfo = os.userInfo();
let username = uinfo.username;

if ( username == 'CAT2022' ) 
    username = 'CAT2022.PUBLIC';


const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

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

function getRandomCode(n) {
    const min = Math.pow(10, n - 1);
    const max = Math.pow(10, n) - 1;

    return crypto.randomInt(min, max + 1).toString();
}

function isNullOrWhitespace(str) {
    if (typeof str === "undefined" || str === null ) {
        return true;
    }

    if (!(typeof str === "string")) return true;

    return !str || !str.trim();
}

function logmsg(msgstr) {
    let callername = getCallerName();

    let prelude = `|${modulename}|${scriptfname}|${String(
        process.pid
    )}|${callername}`;
    let msgout = "";

    if (msgstr instanceof Error) {
        msgout = prelude + "|" + util.inspect(msgstr);
    } else if (typeof msgstr === "string") {
        msgout = prelude + "|" + msgstr;
    }

    console.log(msgout);

    if (!isNullOrWhitespace(logfpath))
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

module.exports = {
    logmsg,
    getTimestamp,
    isNullOrWhitespace,
    getRandomCode,
    delay,
    username,
    scriptdirpath
};