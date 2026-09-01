let helper = require("./nodehostrelay.helper.js");

const path = require("path");
const net = require("net");
const { fork, exec, spawn } = require("child_process");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");
const util = require("util");
const WebSocket = require("ws");

let ws = null;
let commands = [];
var ws_session_list = [];

// ws_session
Object.defineProperty(globalThis, "ws_session", {
    get() {
        if (!ws_session_list) return null;

        let n = ws_session_list.length;

        return ws_session_list[n - 1];
    },
    configurable: true,
    enumerable: true,
});

// ws_sessionid
Object.defineProperty(globalThis, "ws_sessionid", {
    get() {
        return ws_session.sessionId;
    },
    configurable: true,
    enumerable: true,
});

var payloads = {
    create_new_tab: {
        id: 1,
        method: "Target.createTarget",
        params: {
            url: null,
            newWindow: false,
            browserContextId: null,
            // "width": 10,
            // "height": 10,
            // // "left": 2000,
            // "top": 2000
            // #"windowState": "minimized"
            // #"hidden": True --> has problems/issues
        },
    },

    create_new_window: {
        id: 1,
        method: "Target.createTarget",
        params: {
            url: null,
            newWindow: true,
            width: 10,
            height: 10,
            left: 2000,
            top: 2000,
            windowState: "minimized",
        },
    },

    runtime_eval: {
        id: 1,
        method: "Runtime.evaluate",
        params: {
            expression: null, // should be javascript text here
            returnByValue: true,
        },
    },

    getscreenshot: {
        cmd: "Page.captureScreenshot",
        args: {
            format: "jpeg",
            quality: 80,
            captureBeyondViewport: true,
            fromSurface: true,
        },
    },
};

function ws_open() {
    helper.logmsg(`Connected to Chrome DevTools Protocol`);
}

function ws_message(data) {
    helper.logmsg(`[J3O9] received response from Chrome: ${data}`);

    // {"id":1,"result":{"result":{"type":"undefined"}}}
    // {"id":12131489,"result":{}}

    // {"error":{"code":-32600,"message":"Message must have integer 'id' property"}}

    // { "method":"Runtime.consoleAPICalled",
    //   "params":{
    //      "type":"log",
    //      "args":[ {
    //          "type":"object",
    //          "className":"DOMRect",
    //          "description":"DOMRect",
    //          "objectId":"-530350256592465072.1.1",
    //          "preview":{"type":"object","description":"DOMRect","overflow":true,"properties":[{"name":"x","type":"number","value":"401.4250183105469"},{"name":"y","type":"number","value":"10.199999809265137"},{"name":"width","type":"number","value":"71.375"},{"name":"height","type":"number","value":"35.587501525878906"},{"name":"top","type":"number","value":"10.199999809265137"}]}}

    // { "method":"Target.attachedToTarget",
    //   "params":{
    //          "sessionId":"D533AA7BDBC113EF6593BDDDFD902795",
    //          "targetInfo":{
    //              "targetId":"1F2BC053D43892B0AF82E6F4319EF595",
    //              "type":"page",
    //              "title":"",
    //              "url":"https://www.gmail.com/","attached":true,"canAccessOpener":false,"browserContextId":"EE845A4F7E4D9EEAB76FB782C01C7654"},
    // "waitingForDebugger":false}}

    // {"method":"Inspector.detached","params":{"reason":"target_closed"}} --> if you close browser window
    // {"method":"Page.lifecycleEvent","params":{"frameId":"5C0A440586EBD8417CE284734004D4B2","loaderId":"81022FBDCDEA3FB502F501034D6B7461","name":"networkIdle","timestamp":153774.07128}}
    // {"method":"Page.frameNavigated","params":{"frame":{"id":"B91B9F6D66CF9888F84A2A9463B54E8F","parentId":"4AC1E0A9A800FE522D2841E53A89C4E9","loaderId":"0F3CD7F10637C9707F275AF4BE140562","name":"","url":"about:blank","domainAndRegistry":"","securityOrigin":"://","securityOriginDetails":{"isLocalhost":false},"mimeType":"text/html","adFrameStatus":{"adFrameType":"none","explanations":[]},"secureContextType":"Secure","crossOriginIsolatedContextType":"NotIsolated","gatedAPIFeatures":[]},"type":"Navigation"}}
    // {"method":"Page.frameStartedLoading","params":{"frameId":"B91B9F6D66CF9888F84A2A9463B54E8F"}}
    // {"method":"Page.frameStoppedLoading","params":{"frameId":"B91B9F6D66CF9888F84A2A9463B54E8F"}}

    // id, result, exceptionDetails

    let responseobj = JSON.parse(data);

    if (Object.hasOwn(responseobj, "method")) {
        if (responseobj.method == "Target.attachedToTarget") {
            let params = responseobj.params;

            if (
                Object.hasOwn(params.targetInfo, "type") &&
                params.targetInfo["type"] == "page"
            ) {
                ws_session_list.push(params);
            }
        }

        return;
    }

    if (!Object.hasOwn(responseobj, "id")) {
        return;
    }

    let command = commands.find((c) => {
        if (!Object.hasOwn(c, "id")) return false;

        return String(c.id) == String(responseobj.id);
    });

    if (command) command["response"] = responseobj;
}

function ws_error(err) {
    // Unexpected server response: 500
    helper.logmsg(err);
}

async function waitForSocket(delay = 1) {
    while (!(ws.readyState === WebSocket.OPEN)) {
        await helper.delay(1000 * delay);
    }
}

async function ws_send_cmd(command, sendToBrowser = false, catherr = false) {
    let ret = await ws_send(command, sendToBrowser);
    response = await awaitresponse(command);

    if ( catherr && isResponseError(response) ) {
        let err = new Error('response has error');
        err.payload = response.result.result;
        throw err;
    }

    return response;
}

async function ws_send(
    command,
    sendToBrowser = false,
    delayn = 1,
    delay = 1,
    postdelayn = 1,
    postdelay = 1
) {
    if (!sendToBrowser) {
        if (!ws_session) {
            throw new Error("ws session is null");
        } else if (helper.isNullOrWhitespace(ws_session.sessionId)) {
            throw new Error("ws session id is missing");
        }

        command.sessionId = ws_session.sessionId;
    }

    command.id = parseInt(helper.getRandomCode(8), 10);

    let jsonstr = JSON.stringify(command);

    command.ts = helper.getTimestamp();
    commands.push(command);

    helper.logmsg(`sending message: ${jsonstr}`);

    delay = delay || 0;
    delayn = delayn || 0;

    let i = 0;
    while (!(ws.readyState === WebSocket.OPEN)) {
        if (delayn >= 0 && i >= delayn) break;

        await helper.delay(1000 * delay);

        i++;
    }

    if (ws.readyState === WebSocket.OPEN) {
        let ret = ws.send(jsonstr);

        let i = 0;
        postdelayn = postdelayn || 0;
        postdelay = postdelay || 0;
        while (i < postdelayn) {
            await helper.delay(1000 * postdelay);
            i++;
        }

        return ret;
    }

    return {
        error: true,
        msg: `WebSocket not open readyState=${ws.readyState}`,
    };
}

function isResponseError(response) {
    if ( ! Object.hasOwn(response, 'result') ) {
        return false;
    }

    let result = response.result;
    
    if ( ! Object.hasOwn(result, 'result') ) {
        return false;
    }

    result = result.result;

    if ( ! Object.hasOwn(result, 'type') ) {
        return false;
    }

    let type = result.type;

    if ( ! Object.hasOwn(result, 'subtype') ) {
        return false;
    }

    if ( type == 'object' && result.subtype == 'error' ) {
        return true;
    }
   
    return false;

    // response.result.result.type == object
    // response.result.result.subtype == error
    // response.result.result.description
}

async function awaitresponse(command, delay = 1, delaymax = 10) {
    delay = delay || 1;
    delaymax = delaymax || 1;
    let i = 0;
    while (true && i < delaymax) {
        let id = command.id;
        let tcommand = commands.find((c) => {
            return c.id == id;
        });

        if (tcommand?.response) {
            return tcommand.response;
        } else {
            await helper.delay(1000 * delay);
            i++;
        }
    }

    return null;
}

function getscreenshot() {
    let payload = { ...payloads["getscreenshot"] };
    payload = structuredClone(payload);
    return payload;
}

function get_dom(pierce = true, depth = -1) {
    let payload = {
        id: 1,
        method: "DOM.getDocument",
        params: {
            depth: depth,
            pierce: pierce,
        },
    };

    return payload;
}

function click_pressed(x_pos, y_pos, button = "left", clickCount = 1) {
    let command = {
        id: 1,
        method: "Input.dispatchMouseEvent",
        params: {
            type: "mousePressed", // mousePressed, mouseReleased, mouseMoved, mouseWheel
            x: x_pos,
            y: y_pos,
            button: button,
            clickCount: clickCount,
        },
    };

    return command;
}

function click_release(x_pos, y_pos, button = "left", clickCount = 1) {
    let command = {
        id: 1,
        method: "Input.dispatchMouseEvent",
        params: {
            type: "mouseReleased", // mousePressed, mouseReleased, mouseMoved, mouseWheel
            x: x_pos,
            y: y_pos,
            button: button,
            clickCount: clickCount,
        },
    };

    return command;
}

async function getTargetInfo() {
    let command = { method: "Target.getTargetInfo" };
    let response = await ws_send_cmd(command);
    return response;
}

async function getBodyText() {
    let command = runtime_eval(`document.body.innerText`); // document.body.textContent document.body.innerText
    let response = await ws_send_cmd(command);

    let text = response?.result.result.value;

    return text;
}

async function click(x_pos, y_pos) {
    let command = click_pressed(x_pos, y_pos);
    let ret = await ws_send(command);
    let response = await awaitresponse(command);

    command = click_release(x_pos, y_pos);
    ret = await ws_send(command);
    response = await awaitresponse(command);

    return response;
}

function isInitPage(bodyText, url=null, title=null) {
    let keywords = [ "Learn more", "Agree", "No thanks", "Sign in", "Create an account" ];

    
}

function isInboxPage(response) {
    /*
        {
        targetInfo: {
            targetId: "85104882AD75053706129AB4E762E038",
            type: "page",
            title: "Inbox (1) - michaelbradfield2@gmail.com - Gmail",
            url: "https://mail.google.com/mail/u/0/#inbox",
            attached: true,
            canAccessOpener: false,
            browserContextId: "8DCA4AF3D9C99FBCD94A2E9ADCC99828",
        },
    */

    let result = null;

    if (Object.hasOwn(response,'result') )
        result = response.result;
    else
        return false;

    if ( Object.hasOwn(result, 'targetInfo') ) {
        result = result.targetInfo;
        
        let title = result.title; 

        if ( title.includes('Inbox') && title.includes('Gmail') ) {
            return true;
        }
    }

    return false;
}

function getBoxModel(nodeid) {
    let command = {
        id: 1,
        method: "DOM.getBoxModel",
        params: {
            nodeId: nodeid,
        },
    };

    return command;
}

function describeNode(nodeid) {
    let command = {
        method: "DOM.describeNode",
        params: {
            nodeId: nodeid,
            depth: 1,
        },
    };

    return command;
}

function domquerySelectorAll(nodeid, selector) {
    let command = {
        id: 2,
        method: "DOM.querySelectorAll",
        params: {
            nodeId: nodeid,
            selector: selector, //css
        },
    };

    return command;
}

function navigate(url) {
    let payload = {
        id: 1,
        method: "Page.navigate",
        params: {
            url: `${url}`,
        },
    };
    return payload;
}

async function get_windowloc() {

    let command = helper_ws.runtime_eval(
        `window.location.href + '|' + document.title`
    );

    let response = await helper_ws.ws_send_cmd(command);
    // response.result.result.value = url | title

    // response.result.result.type == object
    // response.result.result.subtype == error
    // response.result.result.description

}

function runtime_eval(script) {
    let payload = { ...payloads["runtime_eval"] };
    payload = structuredClone(payload);
    payload.params.expression = script;
    return payload;
}

function create_new_tab(
    url = "https://www.gmail.com/",
    browserContextId = null
) {
    let payload = { ...payloads["create_new_tab"] };
    payload = structuredClone(payload);

    if (helper.isNullOrWhitespace(browserContextId)) {
        if (Object.hasOwn(payload.params, "browserContextId"))
            delete payload.params.browserContextId;
    } else {
        payload.params["browserContextId"] = browserContextId;
    }

    payload.params.url = url;
    return payload;
}

function create_new_window(url = "https://www.gmail.com") {
    let payload = { ...payloads["create_new_window"] };
    payload = structuredClone(payload);

    payload.params.url = url;
    return payload;
}

// TODO refactor to use Target.getTargets instead of pinging http endpoint
async function scan_chrome_targets(debugport = 9223) {
    let response = await helper.ping_chrome(debugport, "json/list");

    let resobj = JSON.parse(response);

    // TODO filter by url to match create_new_window
    resobj = resobj.filter((element, index, array) => {
        return element.url?.startsWith("https://") && element.type === "page";
    });

    let ws_target_url = "";
    if (resobj && resobj.length <= 0) {
        return null;
    } else {
        ws_target_url = resobj[0].webSocketDebuggerUrl;
    }

    return ws_target_url;
}

async function ping_chrome(debugport, path = "json/version") {
    if (!helper.isNullOrWhitespace(path) && !path.startsWith("/")) {
        path = "/" + path;
    }

    const response = await fetch(`http://localhost:${debugport}${path}`);
    let responsetxt = await response.text();
    const cleanString = responsetxt.replace(/\r?\n|\r/g, "");

    return cleanString;
}

function connectToTarget(targetUrl) {
    helper.logmsg(`Connecting to: ${targetUrl}`);

    const ws = new WebSocket(targetUrl);

    ws.on("open", () => {
        ws_open();
    });

    ws.on("message", (data) => {
        let txt = data.toString();
        ws_message(txt);
    });

    ws.on("error", (err) => {
        ws_error(err);
    });

    return ws;
}

async function connectToChrome(debugport) {
    const response = await ping_chrome(debugport, "json/version");
    const targets = JSON.parse(response); //await response.json();

    // ws://127.0.0.1:9223/devtools/browser/80d329c6-bce8-482a-8cf8-859425508382
    // 'ws://localhost:9223/devtools/browser/80d329c6-bce8-482a-8cf8-859425508382'
    ws_url = targets.webSocketDebuggerUrl;

    // ws_url = "ws://localhost:9222/devtools/page/"+targetid
    ws = connectToTarget(ws_url);

    return ws;
}

async function get_tabs(debugport = 9223) {
    let response = await ping_chrome(debugport, "json/list");

    let resobj = JSON.parse(response);

    resobj = resobj.filter((element, index, array) => {
        return element.url?.startsWith("https://") && element.type === "page";
    });

    return resobj;
}

async function setAutoAttach() {
    let command = {
        id: 1,
        method: "Target.setAutoAttach",
        params: {
            autoAttach: true, // Enable auto-attaching to related targets
            waitForDebuggerOnStart: false, // Don't pause execution on launch
            flatten: true, // Enables "flat" session access via sessionId
        },
    };

    let ret = await ws_send(command, true);

    let response = await awaitresponse(command);

    return response;
}

async function waitForSession() {
    while (!ws_session) {
        await helper.delay(1000);
    }
}

async function enableDomains() {
    let command = {
        id: 1,
        method: "Page.enable",
    };

    let ret = await ws_send(command);

    command = {
        id: 1,
        method: "Page.setLifecycleEventsEnabled",
        params: {
            enabled: true,
        },
    };

    ret = await ws_send(command);

    command = {
        id: 1,
        method: "DOM.enable",
        params: {},
    };

    ret = await ws_send(command);

    command = {
        id: 1,
        method: "Runtime.enable",
        params: {},
    };

    ret = await ws_send(command);

    command = {
        id: 1,
        method: "Overlay.enable",
        params: {},
    };

    ret = await ws_send(command);
}

module.exports = {
    ping_chrome,
    connectToTarget,
    get_dom,
    connectToChrome,
    get_tabs,
    scan_chrome_targets,
    create_new_window,
    create_new_tab,
    setAutoAttach,
    waitForSession,
    enableDomains,
    ws_send,
    ws_send_cmd,
    waitForSocket,
    click,
    runtime_eval,
    getBodyText,
    getscreenshot,
    getTargetInfo,
    isInboxPage,
    get_windowloc,
    isResponseError,
    isInitPage,
    commands,
    ws_session_list,
    ws,
};
