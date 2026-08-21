// npm install ws

const { getTimestamp } = require("./nodehostrelayhelper.js");

// npm install pubnub
console.log("--- start nodehostrelay.cmdlist.js ---");

let helper = null;
helper = require("./nodehostrelayhelper.js");


console.log(typeof helper);
console.log(Object.keys(helper));

helper.logmsg("start cmdslist");

let childp = null;

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

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

let ws = null;
let ws_url = '';

(async () => {

    try {
        // might be worth scanning for chrome processes, get cmd line args and see if rdp flag is set

        // { Node: '', CommandLine: '', Name: 'System Idle Process', ProcessId: '' }
        let procs = await helper.getProcessList_wmic();

        procs = procs.filter((element, index, array) => {
            let check_a = element.Name?.toLowerCase().includes('chrome');
            let check_b = element.CommandLine?.toLowerCase().includes('remote-debugging-port');
            return check_a && check_b;
        });

        if ( procs.length == 0 ) {
            childp = helper.spawn_chrome("https://www.gmail.com", 9223, false, true);
                                                                                        
        
            await delay(1000);

            procs = await helper.getProcessList_wmic();

            procs = procs.filter((element, index, array) => {
                let check_a = element.Name?.toLowerCase().includes('chrome');
                let check_b = element.CommandLine?.toLowerCase().includes('remote-debugging-port');
                helper.logmsg(element.CommandLine);
                return check_a && check_b;
            });

        }

        // TODO: confirm debug port is 9223
        
        if ( procs.length == 0 ) {
            // FATAL ERROR -- unable to find chrome process with debug port
            throw new Error('could not launch or find chrome process with debug port');
        }

        let ret = await helper.connectToChrome(9223, ws_open, ws_message, ws_error);
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
