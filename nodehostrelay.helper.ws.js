
const path = require("path");
const net = require("net");
const { fork, exec, spawn } = require("child_process");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");
const util = require("util");
const WebSocket = require("ws");

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

let chrome_debug_path = `C:\\Users\\${username}\\AppData\\Local\\chrome-win64\\chrome.exe`;
let chrome_path = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

module.exports = {
};