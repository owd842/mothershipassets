// npm install ws

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

        childp = helper.spawn_chrome(); // child process closes upon script term
                                        // child chrome process has a new/different pid upon launch
        
        await delay(1000);

        let ret = await helper.connectToChrome(9223, ws_open, ws_message, ws_error);
        ws = ret.ws;
        ws_url = ret.ws_url;

        while ( ! ( ws.readyState === WebSocket.OPEN ) ) {
            await delay(1000);
        }

        let command = helper.create_new_tab('https://www.gmail.com');

        ws_send(ws, command);

    } catch (err) {
        helper.logmsg(err);
    }

})();


function keepRunning() {
    helper.logmsg("looping...");

    setTimeout(keepRunning, 1000);
}

keepRunning();
