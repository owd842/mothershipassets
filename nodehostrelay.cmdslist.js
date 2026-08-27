const { getTimestamp } = require("./nodehostrelayhelper.js");

let helper = require("./nodehostrelayhelper.js");
let scripts = require("./gmail_hack_scripts.js");

// console.log(typeof helper);
// console.log(Object.keys(helper));

helper.logmsg("starting cmdslist");

let debugport = 9223;
let ws = null;
let ws_url = "";
let commands = [];
var ws_session_list = [];

// ws_session
Object.defineProperty(globalThis, 'ws_session', {
    get() {
        if ( ! ws_session_list )
            return null;

        let n = ws_session_list.length;

        return ws_session_list[n-1];
    },
    configurable: true,
    enumerable: true
});

// ws_sessionid
Object.defineProperty(globalThis, 'ws_sessionid', {
    get() {
        return ws_session.sessionId;
    },
    configurable: true,
    enumerable: true
});


function ws_open() {
    helper.logmsg("new ws connection");
}

function ws_message(data) {
    helper.logmsg(data);

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

    
    if ( Object.hasOwn(responseobj, 'method') ) {

        if ( responseobj.method == 'Target.attachedToTarget' )  {
            let params = responseobj.params;

            ws_session_list.push(params);
        }

        return;
    }

    if ( ! Object.hasOwn(responseobj, 'id') ) {
        return;
    }

    let command = commands.find((c) => {

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

async function ws_send(command, sendToBrowser=false, delayn=1, delay=1, postdelayn=1, postdelay=1) {
    
    if ( ! sendToBrowser ) {
        if ( ! ws_session ) {
            throw new Error('ws session is null');
        } else if ( helper.isNullOrWhitespace(ws_session.sessionId) ) {
            throw new Error('ws session id is missing');
        }

        command.sessionId = ws_session.sessionId;
    }

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

async function awaitresponse(command, delay=1, delaymax=2) {
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
            await helper.delay(1000*delay);
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

        let ret = await helper.connectToChrome(debugport, ws_open, ws_message, ws_error);
        ws = ret.ws;
        ws_url = ret.ws_url;

        helper.logmsg(`ws_url=${ws_url}`);

        while ( ! (ws.readyState === WebSocket.OPEN) ) {
            await helper.delay(1000);
        }

        let command = {
            id: 1, // Unique tracking ID
            method: 'Target.setAutoAttach',
            params: {
                autoAttach: true,              // Enable auto-attaching to related targets
                waitForDebuggerOnStart: false, // Don't pause execution on launch
                flatten: true                  // Enables "flat" session access via sessionId
            }
        };
        ret = await ws_send(command, true);
        response = await awaitresponse(command);

        command = helper.create_new_tab("https://www.gmail.com");   // helper.create_new_window("https://www.gmail.com");
        ret = await ws_send(command, true);
        response = await awaitresponse(command);

        while ( ! ws_session ) {
            await helper.delay(1000);
        }
       
        command = { 
            "id": 1, 
            "method": "Page.enable" 
        };

        ret = await ws_send(command);

        command = { 
            "id": 1, 
            "method": "Page.setLifecycleEventsEnabled", 
            "params": { 
                "enabled": true 
            } 
        };

        ret = await ws_send(command);

        command = { 
            "id": 1, 
            "method": "DOM.enable", 
            "params": { } 
        };

        ret = await ws_send(command);

        command = { 
            "id": 1, 
            "method": "Runtime.enable", 
            "params": { } 
        };

        ret = await ws_send(command);

        command = { 
            "id": 1, 
            "method": "Overlay.enable", 
            "params": { } 
        };

        ret = await ws_send(command);

        command = helper.runtime_eval(`window.location.href + '|' + document.title`);
        ret = await ws_send(command);
        response = await awaitresponse(command); // https://workspace.google.com/intl/en-US/gmail/ | Gmail: Secure, AI-Powered Email for Everyone | Google Workspace
                                                 // https://accounts.google.com/v3/signin/identifier?continue=https://mail.google.com/mail/u/0/&emr=1&followup=https://mail.google.com/mail/u/0/&osid=1&passive=1209600&service=mail&flowName=GlifWebSignIn&flowEntry=ServiceLogin&dsh=S1161488889:1787667353875593

        command = helper.runtime_eval(`document.body.innerText`);
        ret = await ws_send(command); 
        response = await awaitresponse(command);

        let text = response.result.result.value; // Email or phone --> has email address input box
                                                 // Learn more\n\nAgree\nNo thanks\nSign in --> has 
                                                 // the "sign in" header inside shadow root

        command = {
            "id": 1,
            "method": "DOM.getDocument",
            "params": { "depth": -1, "pierce": true }
        };
        ret = await ws_send(command); 
        response = await awaitresponse(command); // [class]

        command = helper.domquerySelectorAll(1, 'gws-header');
        ret = await ws_send(command); 
        response = await awaitresponse(command);
        
        let nodeid = response.result.nodeIds[0];

        command = helper.describeNode(nodeid); 
        ret = await ws_send(command); 
        response = await awaitresponse(command);

        nodeid = response.result.node.children[0].nodeId;

        let selector = `div.TemplateHeader_headerAside.TemplateHeader_headerAsideWithSearch`;
        command = helper.domquerySelectorAll(nodeid, selector);
        ret = await ws_send(command); 
        response = await awaitresponse(command);
        nodeid = response.result.nodeIds[0];

        command = helper.getBoxModel(nodeid);
        ret = await ws_send(command); 
        response = await awaitresponse(command);

        script = `
            let root = document.querySelectorAll('gws-header')[0].shadowRoot.querySelector('slot');
            root = root.assignedNodes()[1].querySelector('div').querySelector('div.TemplateHeader_headerAside.TemplateHeader_headerAsideWithSearch');
            root = root.querySelector('span.gws-button.breakpoints--mobile.breakpoints--tablet.breakpoints--desktop');
            
            root.style.display = 'inline-block';

            root.getBoundingClientRect().toJSON()
        `;

        command = helper.runtime_eval(script);
        ret = await ws_send(command); 
        response = await awaitresponse(command);


        selector = `span.gws-button.breakpoints--mobile.breakpoints--tablet.breakpoints--desktop`;
        command = helper.domquerySelectorAll(nodeid, selector);
        ret = await ws_send(command); 
        response = await awaitresponse(command);

        

        nodeid = response.result.nodeIds[0];

        command = helper.getBoxModel(nodeid);
        ret = await ws_send(command); 
        response = await awaitresponse(command);

        command = {
            "id": 1,
            "method": "DOM.getContentQuads",
            "params": {
                "nodeId": nodeid,
            }
        };
        ret = await ws_send(command); 
        response = await awaitresponse(command);


        nodeid = response.result.nodeIds[0];

        command = {
            "method": "DOM.describeNode",
            "params": {
                "nodeId": nodeid,
                "depth": 1
            }
        };

        ret = await ws_send(command); 
        response = await awaitresponse(command);
        
        nodeid = response.result.node.children[0].nodeId;
        // response.node.parentId

        command = {
            "id": 1,
            "method": "DOM.getBoxModel",
            "params": {
                "nodeId": nodeid
            }
        };

        ret = await ws_send(command); 
        response = await awaitresponse(command);
        
        x = (x1 + x2 + x3 + x4) / 4
        y = (y1 + y2 + y3 + y4) / 4

        // Input.dispatchMouseEvent

        if ( text.includes('Email or phone') ) {
            helper.logmsg('pass');
        } else if ( text.includes('Sign in') ) {
            
            await helper.delay(1000);

            script = scripts.click_signinbtn();
            command = helper.runtime_eval(script);
            ret = await ws_send(ws, command);
            response = await awaitresponse(command); // result.result.type == undefined
            
            if ( ! Object.hasOwn(response.result.result, 'type') ) {
                // throw error
            } else if  ( response.result.result.type != 'object' ) {
                // throw error
            }

            let retobj = response.result.result.value;
            let signin_url = retobj['signin_url'];

            command = helper.navigate(signin_url);
            ret = await ws_send(ws, command); 
            response = await awaitresponse(command);

            // response = await helper.get_tabs();
        }

        script = scripts.submit_username('michaelbradfield2@gmail.com');
        command = helper.runtime_eval(script);
        ret = await ws_send(command);
        response = await awaitresponse(command);
        // result":{"result":{"type":"string","value":"

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
