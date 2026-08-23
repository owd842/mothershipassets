const { getTimestamp } = require("./nodehostrelayhelper.js");

let helper = require("./nodehostrelayhelper.js");

// console.log(typeof helper);
// console.log(Object.keys(helper));

helper.logmsg("starting cmdslist");

let ws = null;
let ws_url = "";
let commands = [];

function ws_open() {
    helper.logmsg("new ws connection");
}

function ws_message(data) {
    helper.logmsg(data);

    // {"error":{"code":-32600,"message":"Message must have integer 'id' property"}}
    // {"method":"Inspector.detached","params":{"reason":"target_closed"}} --> if you close browser window

    let responseobj = JSON.parse(data);

    if ( Object.hasOwn(responseobj, 'error') ) {
        return;
    }

    let command = commands.find((c) => {
        return c.id == responseobj.id;
    });

    if ( command )
        command['response'] = responseobj;
}

function ws_error(err) {
    // Unexpected server response: 500
    helper.logmsg(err);
}

function ws_send(ws, command) {
    command.id = parseInt(helper.getRandomCode(8), 10);
    let jsonstr = JSON.stringify(command);

    command.ts = getTimestamp();
    commands.push(command);

    helper.logmsg(`sending message: ${jsonstr}`);

    if (ws.readyState === WebSocket.OPEN) {
        let ret = ws.send(jsonstr);
        return ret;
    }

    return null;
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

        let procs = await helper.activate_chrome("https://www.bing.com/"); // anchor

        if (!procs || procs.length == 0) {
            throw new Error("could not launch or find chrome process");
        }

        let ret = await helper.connectToChrome(9223, ws_open, ws_message, ws_error);
        ws = ret.ws;
        ws_url = ret.ws_url;

        helper.logmsg(`ws_rul=${ws_url}`);

        while (!(ws.readyState === WebSocket.OPEN)) {
            await helper.delay(1000);
        }

        // let command = helper.create_new_tab("https://www.gmail.com");
        let command = helper.create_new_window("https://www.gmail.com");

        ret = ws_send(ws, command);

        await helper.delay(1000);

        response = await helper.ping_chrome(9223, "json/list");

        let resobj = JSON.parse(response);

        resobj = resobj.filter((element, index, array) => {
            return (
                element.url?.startsWith("https://") && element.type === "page"
            );
        });

        let ws_target_url = "";
        if (resobj && resobj.length <= 0) {
        } else {
            ws_target_url = resobj[0].webSocketDebuggerUrl;
        }

        ws = helper.connectToTarget(
            ws_target_url,
            ws_open,
            ws_message,
            ws_error
        );

        const script = 'console.log("!!test!!");';

        command = {
            id: 1,
            method: "Runtime.evaluate",
            params: { expression: script, returnByValue: true },
        };

        while (!(ws.readyState === WebSocket.OPEN)) {
            await helper.delay(1000);
        }

        ret = ws_send(ws, command);

        // response msg: {"id":1,"result":{"result":{"type":"undefined"}}}

        helper.logmsg("pass");
    } catch (err) {
        helper.logmsg(err);
    }
})();

function keepRunning() {
    helper.logmsg("looping... " + helper.getTimestamp());

    setTimeout(keepRunning, 1000);
}

keepRunning();
