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


(async () => {

    try {

        // let ret = await helper.kill_chrome();

        ret = await helper.activate_chrome('https://www.gmail.com/');
        
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
            return element.url?.startsWith('https://') && ( element.type === 'page' );
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
