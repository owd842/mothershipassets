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

// TODO match incomming response to issued command
function ws_message(data) {
    helper.logmsg(data);

    let responseobj = JSON.parse(data);

    let command = commands.find((c) => {
        c.id == responseobj.id;
    });

    command.response = responseobj;
}

function ws_error(err) {
    helper.logmsg(err);
}

function ws_send(ws, command) {
    command.id = helper.getRandomCode(8);
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

        ret = await helper.activate_chrome("https://www.bing.com/");

        // TODO refactor to return JSON object indicating processid, name, commandline, etc.
        // confirm remote debug port + user data dict
        if (!ret) {
            throw new Error("could not launch or find chrome process");
        }

        ret = await helper.connectToChrome(9223, ws_open, ws_message, ws_error); // TODO might exist several chrome browser instances
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

        let response = await helper.ping_chrome(9223, "json/list");

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
