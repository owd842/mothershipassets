// TODO: move ws logic to nodehostrelayhelper.js

let helper = require("./nodehostrelay.helper.js");
let helper_ws = require("./nodehostrelay.helper.ws.js");
let helper_ps = require("./nodehostrelay.helper.js");

let scripts = require("./gmail_hack_scripts.js");

// console.log(typeof helper);
// console.log(Object.keys(helper));

let debugport = 9223;

helper.logmsg("starting cmdslist");

async function get_gmail_signin_pos() {
    let command = helper_ws.runtime_eval(scripts.signinbtncoords);
    let ret = await ws_send(command); 
    let response = await awaitresponse(command);
    
    if ( ! response?.result?.result?.type == 'object' ) {
        throw new Error('not able to extract coords for ')
    }

    let coords = response.result.result.value;
    let x_pos = ( coords.left + coords.right ) / 2;
    let y_pos = ( coords.top + coords.bottom ) / 2;

    return {x_pos:x_pos, y_pos:y_pos};
}

(async () => {
    try {
        // let ret = await helper.kill_chrome();

        let procs = await helper_ps.activate_chrome("https://www.bing.com/",debugport, false, true, true, 1);

        if (!procs || procs.length == 0) {
            throw new Error(`could not launch or find valid chrome process with debug port ${debugport}`);
        }

        let ws = await helper_ws.connectToChrome(debugport, ws_open, ws_message, ws_error);
        
        while ( ! (ws.readyState === WebSocket.OPEN) ) {
            await helper.delay(1000);
        }

        let response = await helper_ws.setAutoAttach();

        command = helper.create_new_tab("https://www.gmail.com");   // helper.create_new_window("https://www.gmail.com");
        ret = await ws_send(command, true);
        response = await awaitresponse(command);

        await helper_ws.waitForSession();
       
        await helper_ws.enableDomains();

        command = helper_ws.runtime_eval(`window.location.href + '|' + document.title`);
        ret = await ws_send(command);
        response = await awaitresponse(command); // https://workspace.google.com/intl/en-US/gmail/ | Gmail: Secure, AI-Powered Email for Everyone | Google Workspace
                                                 // https://accounts.google.com/v3/signin/identifier?continue=https://mail.google.com/mail/u/0/&emr=1&followup=https://mail.google.com/mail/u/0/&osid=1&passive=1209600&service=mail&flowName=GlifWebSignIn&flowEntry=ServiceLogin&dsh=S1161488889:1787667353875593

        command = helper_ws.runtime_eval(`document.body.innerText`);
        ret = await ws_send(command); 
        response = await awaitresponse(command);

        let text = response.result.result.value; // Email or phone --> has email address input box
                                                 // Learn more\n\nAgree\nNo thanks\nSign in 
                                                 // --> has the "sign in" header inside shadow root

        if ( ! text.includes('Sign in') ) {
            throw new Error('sign in page expected');
        }
        
        // ? why do we need this
        command = helper_ws.get_dom();
        ret = await ws_send(command); 
        response = await awaitresponse(command);

        if ( text.includes('Email or phone') ) {    // username/password input page
            helper.logmsg('pass');
        } else if ( text.includes('Sign in') ) {     // sign in button page
            let coords = await get_gmail_signin_pos;
            let x_pos = coords.x_pos; 
            let y_pos = coords.y_pos;
            helper_ws.click(x_pos, y_pos);
        }

        await helper.delay(100*1000);

        let script = scripts.submit_username('michaelbradfield2@gmail.com');
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
