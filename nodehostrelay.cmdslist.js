const { getTimestamp } = require("./nodehostrelayhelper.js");

let helper = require("./nodehostrelayhelper.js");

console.log(typeof helper);
console.log(Object.keys(helper));

helper.logmsg("start cmdslist");

let ws = null;
let ws_url = '';

function ws_open() {
    helper.logmsg('new ws connection');
}

function ws_message(data) {
    helper.logmsg(data);
}

function ws_error(err) {
    helper.logmsg(err);
}

function ws_send(ws, command) {

    let jsonstr = JSON.stringify(command);
    if ( ws.readyState === WebSocket.OPEN ) {
        return ws.send(jsonstr);
    }

}

function isPidAlive(pid) {
    if (pid <= 0) {
        return false;
    }

    try {
        // Signal 0 tests for process existence without modifying it
        process.kill(pid, 0);
        return true;
    } catch (error) {
        // ESRCH means the process was not found
        return error.code === "EPERM"; // True if it exists but you lack permissions
    }
}

async function is_chrome_active(debugport=9223) {
    
    // [ { Node: '', CommandLine: '', Name: 'System Idle Process', ProcessId: '' } ]
    let procs = await helper.getProcessList_wmic();

    procs = procs.filter((element, index, array) => {
        let check_a = element.Name?.toLowerCase().includes('chrome');
        let check_b = element.CommandLine?.toLowerCase().includes('remote-debugging-port');
        return check_a && check_b;
    });

    // TODO check if one of the procs has debugport=${debugport}

    return procs && procs.length > 0;
}

// note: spawning chrome process --> results in a PID that differs from launch
// ! can't use isPidAlive to check if pid is active
async function activate_chrome(start_url="https://www.gmail.com", debugport=9223, headless=false, unref=false) {

    let isactive = await is_chrome_active();

    if ( isactive )
        return true;

    childp = helper.spawn_chrome(start_url, debugport, headless, unref);

    await delay(2000);

    isactive = await is_chrome_active();

    return isactive;
}

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

(async () => {

    try {

        let ret = await activate_chrome('https://www.gmail.com/');
        
        if ( ! ret ) {
            throw new Error('could not launch or find chrome process');
        }

        ret = await helper.connectToChrome(9223, ws_open, ws_message, ws_error);
        ws = ret.ws;
        ws_url = ret.ws_url;

        while ( ! ( ws.readyState === WebSocket.OPEN ) ) {
            await delay(1000);
        }

        let command = helper.create_new_tab('https://www.gmail.com');

        ws_send(ws, command);

        await delay(1000);

        let response = await helper.ping_chrome(9223, 'json/list');

        let resobj = JSON.parse(response);

        resobj = resobj.filter((element, index, array) => {
            return element.url?.startsWith('https://');
        });

        logmsg('pass');

    } catch (err) {
        helper.logmsg(err);
    }

})();


function keepRunning() {
    helper.logmsg("looping... "+helper.getTimestamp());

    setTimeout(keepRunning, 1000);
}

keepRunning();
