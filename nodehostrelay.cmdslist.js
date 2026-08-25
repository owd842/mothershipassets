const { getTimestamp } = require("./nodehostrelayhelper.js");

let helper = require("./nodehostrelayhelper.js");
let scripts = require("./gmail_hack_scripts.js");

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

    // {"id":1,"result":{"result":{"type":"undefined"}}}
    // {"id":12131489,"result":{}}
    
    // {"error":{"code":-32600,"message":"Message must have integer 'id' property"}}

    // {"method":"Inspector.detached","params":{"reason":"target_closed"}} --> if you close browser window
    // {"method":"Page.lifecycleEvent","params":{"frameId":"5C0A440586EBD8417CE284734004D4B2","loaderId":"81022FBDCDEA3FB502F501034D6B7461","name":"networkIdle","timestamp":153774.07128}}
    // {"method":"Page.frameNavigated","params":{"frame":{"id":"B91B9F6D66CF9888F84A2A9463B54E8F","parentId":"4AC1E0A9A800FE522D2841E53A89C4E9","loaderId":"0F3CD7F10637C9707F275AF4BE140562","name":"","url":"about:blank","domainAndRegistry":"","securityOrigin":"://","securityOriginDetails":{"isLocalhost":false},"mimeType":"text/html","adFrameStatus":{"adFrameType":"none","explanations":[]},"secureContextType":"Secure","crossOriginIsolatedContextType":"NotIsolated","gatedAPIFeatures":[]},"type":"Navigation"}}
    // {"method":"Page.frameStartedLoading","params":{"frameId":"B91B9F6D66CF9888F84A2A9463B54E8F"}}
    // {"method":"Page.frameStoppedLoading","params":{"frameId":"B91B9F6D66CF9888F84A2A9463B54E8F"}}

    let responseobj = JSON.parse(data);

    if ( Object.hasOwn(responseobj, 'error') ) {
        return;
    } else if ( Object.hasOwn(responseobj, 'method') ) {
        return;
    }


    let command = commands.find((c) => {
        if ( ! Object.hasOwn(responseobj, 'id') )
            return false;

        if ( ! Object.hasOwn(c, 'id') )
            return false;

        return String(c.id) == String(responseobj.id);
    });

    if ( command )
        command['response'] = responseobj;
}

function ws_error(err) {
    // Unexpected server response: 500
    helper.logmsg(err);
}

async function ws_send(ws, command, delayn=1, delay=1, postdelayn=1, postdelay=1) {
    command.id = parseInt(helper.getRandomCode(8), 10);
    let jsonstr = JSON.stringify(command);

    command.ts = getTimestamp();
    commands.push(command);

    helper.logmsg(`sending message: ${jsonstr}`);

    delay = delay || 0;
    delayn = delayn || 0;

    let i = 0;
    while ( ! (ws.readyState === WebSocket.OPEN) ) {

        if ( delayn >= 0 && i >= delayn )
            break;

        await helper.delay(1000*delay);

        i++;
    }

    if (ws.readyState === WebSocket.OPEN) {
        let ret = ws.send(jsonstr);

        let i = 0;
        postdelayn = postdelayn || 0;
        postdelay = postdelay || 0;
        while ( i <  postdelayn ) {
            await helper.delay(1000*postdelay);
            i++;
        }

        return ret;
    }

    return { error:true, msg:`WebSocket not open readyState=${ws.readyState}` };
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

async function awaitresponse(command, delay=1, delaymax=10) {
    delay = delay || 1;
    delaymax = delaymax || 1;
    let i = 0;
    while ( true && (i < delaymax) ) {
        let id = command.id;
        let tcommand = commands.find(c => {
            return c.id == id;
        });
        
        if ( tcommand.response ) {
            return tcommand.response;
        } else {
            await delay(1000*delay);
            i++;
        }
    }

    return null;
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

        while ( ! (ws.readyState === WebSocket.OPEN) ) {
            await helper.delay(1000);
        }

        // let command = helper.create_new_tab("https://www.gmail.com");
        let command = helper.create_new_window("https://www.gmail.com");

        ret = await ws_send(ws, command);

        response = await helper.ping_chrome(9223, "json/list");

        let resobj = JSON.parse(response);

        // TODO filter by url to match create_new_window
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

        command = { 
            "id": 1, 
            "method": "Page.enable" 
        };

        ret = await ws_send(ws, command);

        command = { 
            "id": 1, 
            "method": "Page.setLifecycleEventsEnabled", 
            "params": { 
                "enabled": true 
            } 
        };

        ret = await ws_send(ws, command);

        command = helper.runtime_eval(`window.location.href + '|' + document.title`);
        ret = await ws_send(ws, command);
        response = await awaitresponse(command); // https://workspace.google.com/intl/en-US/gmail/ | Gmail: Secure, AI-Powered Email for Everyone | Google Workspace
                                                 // https://accounts.google.com/v3/signin/identifier?continue=https://mail.google.com/mail/u/0/&emr=1&followup=https://mail.google.com/mail/u/0/&osid=1&passive=1209600&service=mail&flowName=GlifWebSignIn&flowEntry=ServiceLogin&dsh=S1161488889:1787667353875593

        command = helper.runtime_eval(`document.body.innerText`);
        ret = await ws_send(ws, command); 
        response = await awaitresponse(command);

        let text = response.result.result.value; // Email or phone --> has email address input box
                                                 // Learn more\n\nAgree\nNo thanks\nSign in

        // TODO determine if tab has navigated to correct login page
        if ( text.includes('Email or phone') ) {
            logmsg('pass');
        } else if ( text.includes('Sign in') ) {
            // will create a new tab
            await helper.delay(2000);
            script = scripts.click_signin();
            command = helper.runtime_eval(script);
            ret = await ws_send(ws, command);
            response = await awaitresponse(command); // result.result.type == undefined

            response = await helper.get_tabs();
        }

        script = scripts.enter_email('michaelbradfield2@gmail.com');
        command = helper.runtime_eval(script);
        ret = await ws_send(ws, command);
        response = await awaitresponse(command);
        // result":{"result":{"type":"string","value":"

        command = helper.runtime_eval(script);
        ret = await ws_send(ws, command);

        // should create new tab -- find tab and enter username/password
        response = await helper.ping_chrome(9223, "json/list");

        resobj = JSON.parse(response);

        resobj = resobj.filter((element, index, array) => {
            return (
                element.url?.startsWith("https://") && element.type === "page"
            );
        });

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
